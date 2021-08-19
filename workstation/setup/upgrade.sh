#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/upgrade.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SCRIPT_START_TIME="$(date -u +%s)"

echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA UPGRADE SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "------------------------------------------------"

UPGRADE_PLAN_FILE=$(globFile UPGRADE_PLAN)
UPGRADE_PLAN_RES_FILE=$(globFile UPGRADE_PLAN_RES)
UPGRADE_PLAN_RES64_FILE=$(globFile UPGRADE_PLAN_RES64)
jsonParse "plan.resources" $UPGRADE_PLAN_FILE $UPGRADE_PLAN_RES_FILE
(jq -rc '.[] | @base64' $UPGRADE_PLAN_RES_FILE 2> /dev/null || echo -n "") > $UPGRADE_PLAN_RES64_FILE

if ($(isFileEmpty "$UPGRADE_PLAN_RES64_FILE")) ; then
    echoErr "ERROR: Failed to querry upgrade plan resources info"
    exit 1
fi

UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)

if [ "${INFRA_MODE,,}" == "validator" ] ; then
    UPGRADE_PAUSE_ATTEMPTED=$(globGet UPGRADE_PAUSE_ATTEMPTED)
    if [ "${INFRA_MODE,,}" == "validator" ] && [ "${UPGRADE_INSTATE,,}" == "true" ] && [ "${UPGRADE_PAUSE_ATTEMPTED,,}" == "false" ] ; then
        echoInfo "INFO: Infra is running in the validator mode. Attempting to pause the validator in order to perform safe in-state upgrade!"
        globSet "UPGRADE_PAUSE_ATTEMPTED" "true"
        VFAIL="false" && docker exec -i validator /bin/bash -c ". /etc/profile && pauseValidator validator" || VFAIL="true"

        [ "${VFAIL,,}" == "true" ] && echoWarn "WARNING: Failed to pause validator node" || echoInfo "INFO: Validator node was sucesfully paused"
    fi
fi

UPGRADE_REPOS_DONE=$(globGet UPGRADE_REPOS_DONE)
if [ "${UPGRADE_REPOS_DONE,,}" == "false" ] ; then
    while IFS="" read -r row || [ -n "$row" ] ; do
        sleep 0.1
        jobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
        joid=$(echo "$jobj" | jsonQuickParse "id" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$joid")) && echoWarn "WARNING: Undefined plan id" && continue
        repository=$(echo "$jobj" | jsonParse "git" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$repository")) && echoErr "ERROR: Repository of the plan '$joid' was undefined" && sleep 10 && exit 1
        checkout=$(echo "$jobj" | jsonParse "checkout" 2> /dev/null || echo -n "")
        checksum=$(echo "$jobj" | jsonParse "checksum" 2> /dev/null || echo -n "")
        if ($(isNullOrWhitespaces "$checkout")) && ($(isNullOrWhitespaces "$checksum")) ; then
            echoErr "ERROR: Checkout ('$checkout') or Checksum ('$checksum') was undefined"
            sleep 10
            exit 1
        fi

        REPO_ZIP="/tmp/repo.zip"
        REPO_TMP="/tmp/repo"
        rm -fv $REPO_ZIP
        cd $HOME && rm -rfv $REPO_TMP
        mkdir -p $REPO_TMP && cd "$REPO_TMP"

        if (! $(isNullOrWhitespaces "$checkout")) ; then
            echoInfo "INFO: Fetching '$joid' repository from git..."
            $KIRA_SCRIPTS/git-pull.sh "$repository" "$checkout" "$REPO_TMP" 555 || DOWNLOAD_SUCCESS="false"
            cd "$REPO_TMP"
            zip -9 -r -v "$REPO_ZIP" .* || DOWNLOAD_SUCCESS="false"
        else
            echoInfo "INFO: Downloading '$joid' repository from external file..."
            wget "$repository" -O $REPO_ZIP || DOWNLOAD_SUCCESS="false"
        fi

        if [ "$DOWNLOAD_SUCCESS" == "true" ] && [ -f "$REPO_ZIP" ]; then
            echoInfo "INFO: Download or Fetch of '$joid' repository suceeded"
            if (! $(isNullOrWhitespaces "$checksum")) ; then
                cd $HOME && rm -rfv $REPO_TMP
                mkdir -p $REPO_TMP
                unzip -: $KM_ZIP -d $REPO_TMP
                chmod -R -v 555 $REPO_TMP
                REPO_HASH=$(CDHelper hash SHA256 -p="$REPO_TMP" -x=true -r=true --silent=true -i="$REPO_TMP/.git,$REPO_TMP/.gitignore")
                rm -rfv $REPO_TMP

                if [ "$REPO_HASH" != "$checksum" ] ; then
                    echoInfo "INFO: Checksum verification suceeded"
                else
                    echoErr "ERROR: Chcecksum verification failed, expected '$checksum', but got '$REPO_HASH'"
                    sleep 10
                    exit 1
                fi
            fi
        else
            echoErr "ERROR: Failed to download '$joid' repository"
            sleep 10
            exit 1
        fi

        if ($(isLetters "$joid")) ; then
            CDHelper text lineswap --insert="${joid^^}_CHECKSUM=$checksum" --prefix="${joid^^}_CHECKSUM=" --path=$ETC_PROFILE --append-if-found-not=True
            CDHelper text lineswap --insert="${joid^^}_BRANCH=$checkout" --prefix="${joid^^}_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
            CDHelper text lineswap --insert="${joid^^}_CHECKSUM=$checksum" --prefix="${joid^^}_CHECKSUM=" --path=$ETC_PROFILE --append-if-found-not=True
        else
            echoWarn "WARNING: Unknown plan id '$joid'"
        fi
    done < $UPGRADE_PLAN_RES64_FILE

    echoInfo "INFO: Starting update service..."
    globSet UPGRADE_REPOS_DONE "true"
    globSet UPDATE_FAIL_COUNTER "0"
    globSet UPDATE_DONE "false"
    systemctl daemon-reload
    systemctl start kiraup 
fi

UPGRADE_REPOS_DONE=$(globGet UPGRADE_REPOS_DONE)
UPGRADE_UNPAUSE_ATTEMPTED=$(globGet UPGRADE_UNPAUSE_ATTEMPTED)
UPDATE_DONE=$(globGet UPDATE_DONE)
if [ "${UPDATE_DONE,,}" == "true" ] && [ "${UPGRADE_REPOS_DONE,,}" == "true" ] ; then
    if [ "${INFRA_MODE,,}" == "validator" ] && [ "${UPGRADE_INSTATE,,}" == "true" ] && [ "${UPGRADE_PAUSE_ATTEMPTED,,}" == "true" ]  && [ "${UPGRADE_UNPAUSE_ATTEMPTED,,}" == "true" ] ; then
        echoInfo "INFO: Infra is running in the validator mode. Attempting to unpause the validator in order to finalize a safe in-state upgrade!"
        globSet "UPGRADE_UNPAUSE_ATTEMPTED" "true"
        VFAIL="false" && docker exec -i validator /bin/bash -c ". /etc/profile && unpauseValidator validator" || VFAIL="true"

        if [ "${VFAIL,,}" == "true" ] ; then
            echoWarn "WARNING: Failed to pause validator node"
        else
            echoInfo "INFO: Validator node was sucesfully unpaused"
            globSet "UPGRADE_DONE" "true"
            globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
        fi
    else
        globSet "UPGRADE_DONE" "true"
        globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    fi
fi

echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPGRADE SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

sleep 10