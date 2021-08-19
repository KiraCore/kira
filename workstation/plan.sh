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

if [ "${PLAN_FAIL,,}" == "true" ] || [ "${UPGRADE_DONE,,}" == "true" ] ; then
    echoInfo "ERROR: KIRA Upgrade Plan Failed ($PLAN_FAIL) or was already finalized ($UPGRADE_DONE), stopping service..."
    sleep 10
    systemctl stop kiraplan
    exit 1
fi

mkdir -p $KIRA_INFRA

if (! $(isNullOrWhitespaces "$UPGRADE_NAME_NEW")) && [ "${UPGRADE_NAME_NEW,,}" != "${UPGRADE_NAME_OLD,,}" ] && [ "${UPDATE_DONE,,}" == "true" ]; then
    echoInfo "INFO: NEW Upgrade scheaduled!"
    if [ "$UPGRADE_TIME" != "0" ] && [ "$LATEST_BLOCK_TIME" != "0" ] && [[ $LATEST_BLOCK_TIME -ge $UPGRADE_TIME ]] && [ "${PLAN_DONE,,}" == "false" ] ; then
        echoInfo "INFO: Upgrade time elapsed, ready to execute new plan!"
        echoInfo "INFO: Attempting kira manager branch discovery"
        KIRA_PLAN=""
        UPGRADE_PLAN_FILE=$(globFile UPGRADE_PLAN)
        UPGRADE_PLAN_RES_FILE=$(globFile UPGRADE_PLAN_RES)
        UPGRADE_PLAN_RES64_FILE=$(globFile UPGRADE_PLAN_RES64)
        jsonParse "plan.resources" $UPGRADE_PLAN_FILE $UPGRADE_PLAN_RES_FILE
        (jq -rc '.[] | @base64' $UPGRADE_PLAN_RES_FILE 2> /dev/null || echo -n "") > $UPGRADE_PLAN_RES64_FILE

        if ($(isFileEmpty "$UPGRADE_PLAN_RES64_FILE")) ; then
            echoWarn "WARNING: Failed to querry resources info"
            KIRA_PLAN=""
        else
            while IFS="" read -r row || [ -n "$row" ] ; do
                sleep 0.1
                jobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
                joid=$(echo "$jobj" | jsonQuickParse "id" 2> /dev/null || echo -n "")
                if [ "${joid,,}" == "kira" ] ; then
                    echoInfo "INFO: KIRA Manager repo plan found"
                    KIRA_PLAN="$jobj"
                    break
                fi
            done < $UPGRADE_PLAN_RES64_FILE
        fi

        if (! $(isNullOrWhitespaces "$KIRA_PLAN")) ; then
            echoInfo "INFO: KIRA Manager upgrade plan was found!"
            repository=$(echo "$jobj" | jsonParse "git" 2> /dev/null || echo -n "")
            checkout=$(echo "$jobj" | jsonParse "checkout" 2> /dev/null || echo -n "")
            checksum=$(echo "$jobj" | jsonParse "checksum" 2> /dev/null || echo -n "")

            DOWNLOAD_SUCCESS="true"
            KM_ZIP="/tmp/kira.zip"
            KM_TMP="/tmp/$KIRA_INFRA"
            rm -fv $KM_ZIP
            cd $HOME && rm -rfv $KM_TMP
            mkdir -p $KM_TMP && cd "$KM_TMP" 

            if (! $(isNullOrWhitespaces "$checkout")) ; then
                echoInfo "INFO: Fetching KIRA Manager repository from git..."
                $KIRA_SCRIPTS/git-pull.sh "$repository" "$checkout" "$KM_TMP" 555 || DOWNLOAD_SUCCESS="false"
                zip -9 -r "$KM_ZIP" . * || DOWNLOAD_SUCCESS="false"
            else
                echoInfo "INFO: Downloading KIRA Manager repository from external file..."
                wget "$repository" -O $KM_ZIP || DOWNLOAD_SUCCESS="false"
            fi

            if [ "$DOWNLOAD_SUCCESS" == "true" ] && [ -f "$KM_ZIP" ]; then
                echoInfo "INFO: Download or Fetch suceeded, veryfying checksum..."
                cd $HOME && rm -rfv $KM_TMP
                mkdir -p $KM_TMP
                unzip $KM_ZIP -d $KM_TMP
                chmod -R -v 555 $KM_TMP
                REPO_HASH=$(CDHelper hash SHA256 -p="$KM_TMP" -x=true -r=true --silent=true -i="$KM_TMP/.git,$KM_TMP/.gitignore")
                rm -rfv $KM_TMP

                if (! $(isNullOrWhitespaces "$checksum")) && [ "$checksum" != "$REPO_HASH" ] ; then
                    echoErr "ERROR: Checksum verificaion failed, invalid SHA256 hash, expected '$checksum', but got '$REPO_HASH'"
                    globSet PLAN_FAIL_COUNT $(($PLAN_FAIL_COUNT + 1))
                else
                    echoInfo "INFO: Success, checksum verified, unzipping..."
                    rm -rfv $KIRA_INFRA && mkdir -p "$KIRA_INFRA"
                    unzip $KM_ZIP -d $KIRA_INFRA
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
    else
        if [ "${PLAN_DONE,,}" == "true" ] ; then
            echoInfo "INFO: Plan was alredy executed, starting upgrade..."
            UPSUCCESS="true" && $KIRA_MANAGER/setup/upgrade.sh || UPSUCCESS="false" 
            if [ "${UPSUCCESS,,}" == "true" ] ; then
                echoInfo "INFO: Upgrade round was sucessfull!"
            else
                echoErr "ERROR: Plan failed during upgrade process!"
                globSet PLAN_FAIL_COUNT $(($PLAN_FAIL_COUNT + 1))
            fi
        else
            echoInfo "INFO: Waiting for upgrade time (${UPGRADE_TIME}/${LATEST_BLOCK_TIME})"
        fi
    fi
else
    echoInfo "INFO: NO new upgrades were scheaduled or update is in progress..."
fi

echoInfo "INFO: To preview logs type 'journalctl -u kiraplan -f --output cat'"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPGRADE PLAN SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

UPGRADE_DONE=$(globGet UPGRADE_DONE)
if [ "${UPGRADE_DONE,,}" == "true" ] ; then
    echoInfo "INFO: Success, upgrade was finalized, stopping plan service..."
    systemctl stop kiraplan
fi

PLAN_FAIL_COUNT=$(globGet PLAN_FAIL_COUNT)
if [[ $PLAN_FAIL_COUNT -ge 10 ]] ; then
    echoErr "ERROR: Plan failed $PLAN_FAIL_COUNT / 10 times, topping kiraplan service..."
    globGet PLAN_FAIL "true"
    
    journalctl --since "$PLAN_START_DT" -u kiraplan -b --no-pager --output cat > "$KIRA_DUMP/kiraplan-done.log.txt" || echoErr "ERROR: Failed to dump kira plan service log"
    systemctl stop kiraplan
fi

sleep 10