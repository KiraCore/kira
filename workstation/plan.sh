#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/plan.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraplan && journalctl -u kiraplan -f --output cat

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_DONE=$(globGet UPDATE_DONE)
PLAN_DONE=$(globGet PLAN_DONE)
PLAN_FAIL=$(globGet PLAN_FAIL)
PLAN_FAIL_COUNT=$(globGet PLAN_FAIL_COUNT)
UPGRADE_NAME_OLD=$(cat $KIRA_INFRA/upgrade || echo "")
UPGRADE_NAME_NEW=$(globGet UPGRADE_NAME)
UPGRADE_DONE=$(globGet UPGRADE_DONE)
PLAN_START_DT=$(globGet PLAN_START_DT)
UPGRADE_TIME=$(globGet "UPGRADE_TIME") && (! $(isNaturalNumber "$UPGRADE_TIME")) && UPGRADE_TIME=0
LATEST_BLOCK_TIME=$(globGet LATEST_BLOCK_TIME) && (! $(isNaturalNumber "$LATEST_BLOCK_TIME")) && LATEST_BLOCK_TIME=0

echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA UPGRADE & SETUP SERVICE $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|       BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|       UPDATE DONE: ${UPDATE_DONE}"
echoWarn "|         PLAN DONE: ${PLAN_DONE}"
echoWarn "|      UPGRADE DONE: ${UPGRADE_DONE}"
echoWarn "|  UPGRADE NAME OLD: ${UPGRADE_NAME_OLD}"
echoWarn "|  UPGRADE NAME NEW: ${UPGRADE_NAME_NEW}"
echoWarn "|       PLAN FAILED: ${PLAN_FAIL}"
echoWarn "|   PLAN FAIL COUNT: ${PLAN_FAIL_COUNT}"
echoWarn "|   PLAN START DATE: ${PLAN_START_DT}"
echoWarn "|      UPGRADE TIME: ${UPGRADE_TIME}"
echoWarn "| LATEST BLOCK TIME: ${LATEST_BLOCK_TIME}"
echoWarn "------------------------------------------------"
set -x

[ "${PLAN_FAIL,,}" == "true" ]  && echoErr "ERROR: KIRA Upgrade Plan Failed, stopping service..." && sleep 10 && systemctl stop kiraplan && exit 1
[ "${UPDATE_DONE,,}" != "true" ] && echoWarn "WARNING: KIRA Update must be finalized before upgrade plan can proceed!" && sleep 10 && exit 0

echoInfo "INFO: NEW Upgrade scheaduled!"
if [ "${PLAN_DONE,,}" == "false" ] ; then
    [[ $LATEST_BLOCK_TIME -lt $UPGRADE_TIME ]] && echoInfo "INFO: Waiting for upgrade time (${UPGRADE_TIME}/${LATEST_BLOCK_TIME})" && sleep 10 && exit 0

    mkdir -p $KIRA_INFRA

    echoInfo "INFO: Upgrade time elapsed, ready to execute new plan!"
    globSet KIRA_PLAN ""
    UPGRADE_PLAN_FILE=$(globFile UPGRADE_PLAN)
    UPGRADE_PLAN_RES_FILE=$(globFile UPGRADE_PLAN_RES)
    UPGRADE_PLAN_RES64_FILE=$(globFile UPGRADE_PLAN_RES64)
    jsonParse "plan.resources" $UPGRADE_PLAN_FILE $UPGRADE_PLAN_RES_FILE
    (jq -rc '.[] | @base64' $UPGRADE_PLAN_RES_FILE 2> /dev/null || echo -n "") > $UPGRADE_PLAN_RES64_FILE
                  
    if ($(isFileEmpty "$UPGRADE_PLAN_RES64_FILE")) ; then
        echoWarn "WARNING: Failed to querry resources info"
    else
        echoInfo "INFO: Attempting kira manager branch discovery..."
        while IFS="" read -r row || [ -n "$row" ] ; do
            sleep 0.1
            jobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
            joid=$(echo "$jobj" | jsonQuickParse "id" 2> /dev/null || echo -n "")
            if [ "${joid,,}" == "kira" ] ; then
                echoInfo "INFO: KIRA Manager repo plan found"
                globSet KIRA_PLAN "$jobj"
                break
            else
                echoWarn "WARNING: Plan '$joid' is NOT a 'kira' plan, searching..."
            fi
        done < $UPGRADE_PLAN_RES64_FILE
    fi
                       
    KIRA_PLAN=$(globGet KIRA_PLAN)
    if (! $(isNullOrWhitespaces "$KIRA_PLAN")) ; then
        echoInfo "INFO: KIRA Manager upgrade plan was found!"
        repository=$(echo "$KIRA_PLAN" | jsonParse "git" 2> /dev/null || echo -n "")
        checkout=$(echo "$KIRA_PLAN" | jsonParse "checkout" 2> /dev/null || echo -n "")
        checksum=$(echo "$KIRA_PLAN" | jsonParse "checksum" 2> /dev/null || echo -n "")
                     
        DOWNLOAD_SUCCESS="true"
        KM_ZIP="/tmp/kira.zip"
        KM_TMP="/tmp${KIRA_INFRA}"
        rm -fv $KM_ZIP
        cd $HOME && rm -rfv $KM_TMP
        mkdir -p $KM_TMP && cd "$KM_TMP" 
                      
        if (! $(isNullOrWhitespaces "$checkout")) ; then
            echoInfo "INFO: Fetching KIRA Manager repository from git..."
            $KIRA_SCRIPTS/git-pull.sh "$repository" "$checkout" "$KM_TMP" 555 || DOWNLOAD_SUCCESS="false"
            cd "$KM_TMP" 
            zip -9 -r -v "$KM_ZIP" .* || DOWNLOAD_SUCCESS="false"
        else
            echoInfo "INFO: Downloading KIRA Manager repository from external file..."
            wget "$repository" -O $KM_ZIP || DOWNLOAD_SUCCESS="false"
        fi
             
        if [ "$DOWNLOAD_SUCCESS" == "true" ] && [ -f "$KM_ZIP" ]; then
            echoInfo "INFO: Download or Fetch suceeded, veryfying checksum..."
            cd $HOME && rm -rfv $KM_TMP && mkdir -p $KM_TMP
            unzip -o -: $KM_ZIP -d $KM_TMP
            chmod -R -v 555 $KM_TMP
            REPO_HASH=$(CDHelper hash SHA256 -p="$KM_TMP" -x=true -r=true --silent=true -i="$KM_TMP/.git,$KM_TMP/.gitignore")
            rm -rfv $KM_TMP
              
            if (! $(isNullOrWhitespaces "$checksum")) && [ "$checksum" != "$REPO_HASH" ] ; then
                echoErr "ERROR: Checksum verificaion failed, invalid SHA256 hash, expected '$checksum', but got '$REPO_HASH'"
                globSet PLAN_FAIL_COUNT $(($PLAN_FAIL_COUNT + 1))
            else
                echoInfo "INFO: Success, checksum verified, unzipping..."
                cd $HOME && rm -rfv $KIRA_INFRA && mkdir -p "$KIRA_INFRA"
                unzip -o -: $KM_ZIP -d $KIRA_INFRA
                chmod -R -v 555 $KIRA_INFRA
                      
                rm -rfv $KIRA_MANAGER && mkdir -p "$KIRA_MANAGER"
                cp -rfv "$KIRA_INFRA/workstation/." $KIRA_MANAGER
                chmod -R 555 $KIRA_MANAGER
                  
                if (! $(isNullOrWhitespaces "$checkout")) ; then
                    echoInfo "INFO: Updating branch name and repository address..."
                    CDHelper text lineswap --insert="INFRA_REPO=$repository" --prefix="INFRA_REPO=" --path=$ETC_PROFILE --append-if-found-not=True
                    CDHelper text lineswap --insert="INFRA_BRANCH=$checkout" --prefix="INFRA_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
                    globSet "INFRA_REPO" "$repository"
                    globSet "INFRA_BRANCH" "$checkout"
                fi
                CDHelper text lineswap --insert="INFRA_CHECKSUM=$checksum" --prefix="INFRA_CHECKSUM=" --path=$ETC_PROFILE --append-if-found-not=True
                
                echoInfo "INFO: Updating setup version..."
                SETUP_VER=$(cat $KIRA_INFRA/version || echo "")
                [ -z "SETUP_VER" ] && echoErr "ERROR: Invalid setup release version!" && sleep 10 && exit 1
                CDHelper text lineswap --insert="KIRA_SETUP_VER=$SETUP_VER" --prefix="KIRA_SETUP_VER=" --path=$ETC_PROFILE --append-if-found-not=True
                      
                globSet PLAN_DONE "true"
            fi
        else
            echoErr "ERROR: Failed downloading or fetching KIRA Manager repo!"
            globSet PLAN_FAIL_COUNT $(($PLAN_FAIL_COUNT + 1))
        fi
    else
        echoWarn "WARNING: KIRA Manager upgrade plan was NOT found!"
    fi
fi

if [ "${PLAN_DONE,,}" == "true" ] && [ "${UPGRADE_DONE,,}" == "false" ] ; then
    echoInfo "INFO: Plan was alredy executed, starting upgrade..."
    UPSUCCESS="true" && $KIRA_MANAGER/setup/upgrade.sh || UPSUCCESS="false" 
    if [ "${UPSUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Upgrade round was sucessfull!"
    else
        echoErr "ERROR: Plan failed during upgrade process!"
        globSet PLAN_FAIL_COUNT $(($PLAN_FAIL_COUNT + 1))
    fi
fi

set +x
echoInfo "INFO: To preview logs type 'journalctl -u kiraplan -f --output cat'"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPGRADE PLAN SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x

UPGRADE_DONE=$(globGet UPGRADE_DONE)
if [ "${UPGRADE_DONE,,}" == "true" ] ; then
    echoInfo "INFO: Success, upgrade was finalized, stopping plan service..."
    systemctl stop kiraplan
fi

PLAN_FAIL_COUNT=$(globGet PLAN_FAIL_COUNT)
if [[ $PLAN_FAIL_COUNT -ge 10 ]] ; then
    echoErr "ERROR: Plan failed $PLAN_FAIL_COUNT / 10 times, topping kiraplan service..."
    globSet PLAN_FAIL "true"
    
    journalctl --since "$PLAN_START_DT" -u kiraplan -b --no-pager --output cat > "$KIRA_DUMP/kiraplan-done.log.txt" || echoErr "ERROR: Failed to dump kira plan service log"
    systemctl stop kiraplan
fi

sleep 10