#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/upgrade.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x
SCRIPT_START_TIME="$(date -u +%s)"
PLAN_START_DT=$(globGet PLAN_START_DT)
UPGRADE_EXPORT_DONE=$(globGet UPGRADE_EXPORT_DONE)
UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)
CONTAINERS=$(globGet CONTAINERS)
UPGRADE_PLAN_FILE=$(globFile UPGRADE_PLAN)
UPGRADE_PLAN_RES_FILE=$(globFile UPGRADE_PLAN_RES)
UPGRADE_PLAN_RES64_FILE=$(globFile UPGRADE_PLAN_RES64)
OLD_CHAIN_ID=$(cat "$UPGRADE_PLAN_FILE" | jsonParse "old_chain_id" || echo "")
NEW_CHAIN_ID=$(cat "$UPGRADE_PLAN_FILE" | jsonParse "new_chain_id" || echo "")
CONTAINER_NAME="$(globGet INFRA_MODE)"
COMMON_PATH="$DOCKER_COMMON/${CONTAINER_NAME}"
APP_HOME="$DOCKER_HOME/$CONTAINER_NAME"

set +x
echoC ";whi"  " =============================================================================="
echoC ";whi"  "|$(strFixC "STARTED KIRA UPGRADE SCRIPT $KIRA_SETUP_VER" 78)|"   
echoC ";whi"  "|==============================================================================|"
echoC ";whi"  "|        BASH SOURCE: $(strFixL " ${BASH_SOURCE[0]} " 58)|"
echoC ";whi"  "|    PLAN START DATE: $(strFixL " $PLAN_START_DT " 58)|"
echoC ";whi"  "|        EXPORT DONE: $(strFixL " $UPGRADE_EXPORT_DONE " 58)|"
echoC ";whi"  "|    UPGRADE INSTATE: $(strFixL " $UPGRADE_INSTATE " 58)|"
echoC ";whi"  "|       OLD CHAIN ID: $(strFixL " $OLD_CHAIN_ID " 58)|"
echoC ";whi"  "|       NEW CHAIN ID: $(strFixL " $NEW_CHAIN_ID " 58)|"
echoC ";whi"  "|   TARGET CONTAINER: $(strFixL " $CONTAINER_NAME " 58)|"
echoC ";whi"  "|         CONTAINERS: $(strFixL " $CONTAINERS " 58)|"
echoC ";whi"  " =============================================================================="
set -x

($(isNullOrEmpty "$NEW_CHAIN_ID")) && echoErr "ERROR: Failed to find new chain identifier in the upgrade plan!" && sleep 10 && exit 1
(! $(isBoolean "$UPGRADE_INSTATE")) && echoErr "ERROR: Invalid instate upgrade parameter, expected boolean but got '$UPGRADE_INSTATE'" && sleep 10 && exit 1
[ "$(globGet INFRA_MODE)" != "validator" ] && [ "$(globGet INFRA_MODE)" != "sentry" ] && [ "$(globGet INFRA_MODE)" != "seed" ] && \
    echoErr "ERROR: Unsupported infra mode '$(globGet INFRA_MODE)'" && sleep 10 && exit 1

echoInfo "INFO: Extracting resources from the upgrade plan..."
jsonParse "resources" $UPGRADE_PLAN_FILE $UPGRADE_PLAN_RES_FILE
(jq -rc '.[] | @base64' $UPGRADE_PLAN_RES_FILE 2> /dev/null || echo -n "") > $UPGRADE_PLAN_RES64_FILE

if ($(isFileEmpty "$UPGRADE_PLAN_RES64_FILE")) ; then
    echoErr "ERROR: Failed to querry upgrade plan resources info"
    exit 1
else
    echoInfo "INFO: Success upgrade plan file was found"
fi

if [ "$UPGRADE_EXPORT_DONE" == "false" ] ; then
    echoInfo "INFO: Reading repos info..."

    globDel "NEXT_KIRA_URL" "NEXT_KIRA_VERSION" "NEXT_KIRA_CHECKSUM"
    while IFS="" read -r row || [ -n "$row" ] ; do
        jobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
        joid=$(echo "$jobj" | jsonQuickParse "id" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$joid")) && echoWarn "WARNING: Invalid plan id '$joid'" && continue

        url=$(echo "$jobj" | jsonParse "url" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$url")) && url=$(echo "$jobj" | jsonParse "git" 2> /dev/null || echo -n "")
        version=$(echo "$jobj" | jsonParse "version" 2> /dev/null || echo -n "")
        checksum=$(echo "$jobj" | jsonParse "checksum" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$checksum")) && checksum=$(echo "$jobj" | jsonParse "checkout" 2> /dev/null || echo -n "")
        ($(isNullOrWhitespaces "$checksum")) && checksum="$(globGet KIRA_COSIGN_PUB)"

        globSet "NEXT_${joid}_CHECKSUM" "$checksum"
        globSet "NEXT_${joid}_VERSION" "$version"
        globSet "NEXT_${joid}_URL" "$url"
    done < $UPGRADE_PLAN_RES64_FILE

    if [ "$(globGet INFRA_MODE)" == "validator" ] ; then
        UPGRADE_PAUSE_ATTEMPTED=$(globGet UPGRADE_PAUSE_ATTEMPTED)
        if [ "$(globGet INFRA_MODE)" == "validator" ] && [ "$UPGRADE_PAUSE_ATTEMPTED" == "false" ] ; then
            echoInfo "INFO: Infra is running in the validator mode. Attempting to pause the validator in order to perform safe in-state upgrade!"
            globSet "UPGRADE_PAUSE_ATTEMPTED" "true"
            PAUSE_FAILED="false"
            docker exec -i validator /bin/bash -c ". /etc/profile && pauseValidator validator" || PAUSE_FAILED="true"
            [ "$PAUSE_FAILED" == "true" ] && echoWarn "WARNING: Failed to pause validator node" || echoInfo "INFO: Validator node was sucesfully paused"
        fi
    fi

    echoInfo "INFO: Halting and re-starting all containers..."
    for name in $CONTAINERS; do
        echoInfo "INFO: Halting and re-starting '$name' container..."
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="false"
    done

    echoInfo "INFO: Waiting for contianers to restart..."
    sleep 15

    echoInfo "INFO: Wiping all snapshoots from the '$KIRA_SNAP' directory & old exports..."
    GENESIS_EXPORT="$APP_HOME/genesis-export.json"
    rm -fv $KIRA_SNAP/*.tar || echoErr "ERROR: Failed to wipe *.tar files from '$KIRA_SNAP' directory"
    rm -fv $KIRA_SNAP/*.zip || echoErr "ERROR: Failed to wipe *.zip files from '$KIRA_SNAP' directory"
    rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"
    rm -fv $DOCKER_COMMON_RO/snap.* || echoErr "ERROR: Failed to wipe snap.* files from '$DOCKER_COMMON_RO' directory"
    rm -fv "$GENESIS_EXPORT" "$APP_HOME/addrbook-export.json" "$APP_HOME/priv_validator_state-export.json" "$APP_HOME/old-genesis.json" "$APP_HOME/new-genesis.json" "$APP_HOME/genesis.json"
    globSet KIRA_SNAP_PATH ""

    echoInfo "INFO: Exporting genesis!"
    # NOTE: The $APP_HOME/config/genesis.json might be a symlink, for this reason we MUST copy it using docker exec
    docker exec -i $CONTAINER_NAME /bin/bash -c ". /etc/profile && cp -fv \"$SEKAID_HOME/config/genesis.json\" \"$SEKAID_HOME/old-genesis.json\""
    docker exec -i $CONTAINER_NAME /bin/bash -c ". /etc/profile && sekaid export --home=\$SEKAID_HOME &> \$SEKAID_HOME/genesis-export.json"
    (! $(isFileJson $GENESIS_EXPORT)) && echoErr "ERROR: Failed to export genesis file!" && sleep 10 && exit 1 || echoInfo "INFO: Finished upgrade export!"
    
    # delete old genesis after export is complete
    if [ "$UPGRADE_INSTATE" == "false"] ; then
        echoInfo "INFO: Deleting old genesis since new genesis is required"
        chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
        chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the interx reference direcotry"
        rm -fv "$LOCAL_GENESIS_PATH" "$INTERX_REFERENCE_DIR/genesis.json"
    else
        echoInfo "INFO: Upgrade does NOT require a new genesis file"
    fi
    
    echoInfo "INFO: Starting update service..."
    setGlobEnv NETWORK_NAME "$NEW_CHAIN_ID"
    globSet UPGRADE_EXPORT_DONE "true"
    globSet UPDATE_FAIL_COUNTER "0"
    globSet UPDATE_DONE "false"
    globSet SYSTEM_REBOOT "true"
    globSet SETUP_START_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    globSet SETUP_END_DT ""

    $KIRA_MANAGER/init.sh --infra-src="$(globGet INFRA_SRC)" --init-mode="upgrade"
else
    echoInfo "INFO: Upgrade exports already done!"
fi

UPGRADE_UNPAUSE_ATTEMPTED=$(globGet UPGRADE_UNPAUSE_ATTEMPTED)
UPDATE_DONE=$(globGet UPDATE_DONE)
if [ "$UPDATE_DONE" == "true" ] && [ "$UPGRADE_EXPORT_DONE" == "true" ] ; then
    if [ "$(globGet INFRA_MODE)" == "validator" ] && [ "$UPGRADE_PAUSE_ATTEMPTED" == "true" ]  && [ "$UPGRADE_UNPAUSE_ATTEMPTED" == "true" ] ; then
        echoInfo "INFO: Infra is running in the validator mode. Attempting to unpause the validator in order to finalize a safe in-state upgrade!"
        globSet "UPGRADE_UNPAUSE_ATTEMPTED" "true"
        UNPAUSE_FAILED="false"
        docker exec -i validator /bin/bash -c ". /etc/profile && unpauseValidator validator" || UNPAUSE_FAILED="true"

        if [ "$UNPAUSE_FAILED" == "true" ] ; then
            echoWarn "WARNING: Failed to pause validator node"
        else
            echoInfo "INFO: Validator node was sucesfully unpaused"
            globSet UPGRADE_DONE "true"
            globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
        fi
    else
        globSet UPGRADE_DONE "true"
        globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    fi
fi

set +x
echoC ";whi"  "================================================================================"
echoC ";whi"  "|$(strFixC "FINISHED KIRA UPGRADE SCRIPT $KIRA_SETUP_VER" 78))|"   
echoC ";whi"  "================================================================================"
set -x
sleep 10