#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# fileFollow $(globFile CONTAINERS_SCAN_LOG)
set -x

echo "INFO: Started kira network contianers monitor..."
timerStart MONITOR_CONTAINERS
SCAN_LOGS="$KIRA_SCAN/logs"
NETWORKS=$(globGet NETWORKS)
CONTAINERS=$(globGet CONTAINERS)
INFRA_MODE=$(globGet INFRA_MODE)
IS_SYNCING=$(globGet "${INFRA_MODE}_SYNCING")
TIME_NOW="$(date2unix $(date))"
UPGRADE_TIME=$(globGet UPGRADE_TIME)
CUSTOM_INTERX_PORT="$(globGet CUSTOM_INTERX_PORT)"
DEFAULT_INTERX_PORT="$(globGet DEFAULT_INTERX_PORT)"
(! $(isNaturalNumber "$UPGRADE_TIME")) && UPGRADE_TIME=0

set +x
echoWarn "------------------------------------------------"
echoWarn "|        STARTING: KIRA CONTAINER SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|        KIRA SCAN: $KIRA_SCAN"
echoWarn "|       CONTAINERS: $CONTAINERS"
echoWarn "|         NETWORKS: $NETWORKS"
echoWarn "|       INFRA MODE: $INFRA_MODE"
echoWarn "|       IS SYNCING: $IS_SYNCING"
echoWarn "|  INTERX REF. DIR: $INTERX_REFERENCE_DIR"
echoWarn "|         TIME NOW: $TIME_NOW"
echoWarn "|     UPGRADE TIME: $UPGRADE_TIME"
echoWarn "------------------------------------------------"
sleep 1
set -x

globDel NEW_UPGRADE_PLAN
for name in $CONTAINERS; do
    echoInfo "INFO: Processing container $name"
    mkdir -p "$DOCKER_COMMON/$name" "$SCAN_LOGS"

    PIDX=$(globGet "${name}_STATUS_PID")

    if kill -0 "$PIDX" 2>/dev/null; then
        echoInfo "INFO: $name container status check is still running, see logs '$SCAN_LOGS/${name}-status.error.log' ..."
        continue
    fi

    # cat "$SCAN_LOGS/seed-status.error.log"
    timerStart "${name}_SCAN" 
    globSet "${name}_SCAN_DONE" "false"
    $KIRA_MANAGER/kira/container-status.sh "$name" "$NETWORKS" &> "$SCAN_LOGS/${name}-status.error.log" &
    globSet "${name}_STATUS_PID" "$!"

    if [[ "${name,,}" =~ ^(validator|sentry|seed)$ ]] ; then
        echoInfo "INFO: Fetching sekai status..."
        echo $(timeout 3 curl --fail 0.0.0.0:$(globGet CUSTOM_RPC_PORT)/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") | globSet "${name}_SEKAID_STATUS"
        # TODO: REMOVE DOCKER
        echoInfo "INFO: Fetching upgrade plan..."
        TMP_UPGRADE_PLAN=$(docker exec -i $name bash -c "source /etc/profile && showNextPlan" | jsonParse "plan" || echo "")
        ($(isNullOrEmpty "$TMP_UPGRADE_PLAN")) && TMP_UPGRADE_PLAN=$(docker exec -i $name bash -c "source /etc/profile && showCurrentPlan" | jsonParse "plan" || echo "")
        (! $(isNullOrEmpty "$TMP_UPGRADE_PLAN")) && [ "$(globGet UPGRADE_PLAN)" != "$TMP_UPGRADE_PLAN" ] && globSet NEW_UPGRADE_PLAN "$TMP_UPGRADE_PLAN"
    elif [ "${name,,}" == "interx" ] ; then
        echoInfo "INFO: Fetching sekai & interx status..."

        #INTERX_STATUS_CODE=$(docker exec -t "$CONTAINER_NAME" curl --fail 0.0.0.0:$DEFAULT_INTERX_PORT/api/kira/statu 2>/dev/null || echo -n "")
        #INEX_KIRA_STATUS="$(timeout 3 curl --fail 0.0.0.0:$CUSTOM_INTERX_PORT/api/kira/status 2>/dev/null || echo -n "")"

        echo $(timeout 3 curl --fail 0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/api/kira/status 2>/dev/null || echo -n "") | globSet "${name}_SEKAID_STATUS"
        echo $(timeout 3 curl --fail 0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/api/status 2>/dev/null || echo -n "") | globSet "${name}_INTERX_STATUS"
    fi
done

NEW_UPGRADE_PLAN=$(globGet NEW_UPGRADE_PLAN)
if (! $(isNullOrEmpty "$NEW_UPGRADE_PLAN")) && [ "$(globGet UPDATE_DONE)" == "true" ] && [ "$(globGet UPGRADE_DONE)" == "true" ] && [ "$(globGet PLAN_DONE)" == "true" ] ; then
    echoInfo "INFO: Upgrade plan was found!"
    TMP_UPGRADE_NAME=$(echo "$NEW_UPGRADE_PLAN" | jsonParse "name" || echo "")
    TMP_UPGRADE_TIME=$(echo "$NEW_UPGRADE_PLAN" | jsonParse "upgrade_time" || echo "") 
    TMP_UPGRADE_TIME=$(date2unix "$TMP_UPGRADE_TIME") 
    TMP_UPGRADE_INSTATE=$(echo "$NEW_UPGRADE_PLAN" | jsonParse "instate_upgrade" || echo "")
    TMP_OLD_CHAIN_ID=$(echo "$NEW_UPGRADE_PLAN" | jsonParse "old_chain_id" || echo "")
    TMP_NEW_CHAIN_ID=$(echo "$NEW_UPGRADE_PLAN" | jsonParse "new_chain_id" || echo "")
    (! $(isNaturalNumber "$TMP_UPGRADE_TIME")) && TMP_UPGRADE_TIME=0

    # NOTE!!! Upgrades will only happen if old plan time is older then new plan, otherwise its considered a plan rollback
    if [ "${TMP_UPGRADE_NAME,,}" != "genesis" ] && [ "$TMP_OLD_CHAIN_ID" == "$NETWORK_NAME" ] && [[ $TMP_UPGRADE_TIME -gt $UPGRADE_TIME ]] && [[ $TMP_UPGRADE_TIME -gt $TIME_NOW ]] && ($(isBoolean "$TMP_UPGRADE_INSTATE")) ; then
        echoInfo "INFO: New upgrade plan was found!"

        globSet UPGRADE_TIME "$TMP_UPGRADE_TIME"
        globSet UPGRADE_INSTATE "$TMP_UPGRADE_INSTATE"
        globSet UPGRADE_PLAN "$NEW_UPGRADE_PLAN"
        globSet UPDATE_FAIL_COUNTER "0"
        globSet UPDATE_FAIL "false"
        globSet PLAN_DONE "false"
        globSet PLAN_FAIL "false"
        globSet PLAN_FAIL_COUNT "0"
        globSet UPGRADE_DONE "false"
        globSet UPGRADE_EXPORT_DONE "false"
        globSet UPGRADE_PAUSE_ATTEMPTED "false"
        globSet UPGRADE_UNPAUSE_ATTEMPTED "false"
        globSet PLAN_START_DT "$(date +'%Y-%m-%d %H:%M:%S')"
        globSet PLAN_END_DT ""

        echo -n "" > $KIRA_LOGS/kiraplan.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraplan.log'"
        echo -n "" > $KIRA_LOGS/kiraup.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraup.log'"
        systemctl restart kiraplan
    else
        echoWarn "WARNING:     Upgrade Time: $UPGRADE_TIME -> $TMP_UPGRADE_TIME"
        echoWarn "WARNING: Upgrade Chain Id: $TMP_OLD_CHAIN_ID -> $TMP_NEW_CHAIN_ID"
        echoWarn "WARNING:  Upgrade Instate: $TMP_UPGRADE_INSTATE"
        echoWarn "WARNING:  Upgrade plan will NOT be changed!"
    fi
else
    echoInfo "INFO: No new upgrade plans were found or are not expeted!"
fi

MIN_HEIGHT=$(globGet MIN_HEIGHT $GLOBAL_COMMON_RO)
NEW_LATEST_BLOCK_TIME=$(globGet LATEST_BLOCK_TIME $GLOBAL_COMMON_RO)
NEW_LATEST_BLOCK=0
NEW_LATEST_STATUS=0
CONTAINERS_COUNT=0
NEW_CATCHING_UP="false"
for name in $CONTAINERS; do
    echoInfo "INFO: Waiting for '$name' scan processes to finalize"
    PIDX=$(globGet "${name}_STATUS_PID")
    EXISTS_TMP=$(globGet "${name}_EXISTS")
    [ "${EXISTS_TMP,,}" == "true" ] && CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))

    set +x
    while : ; do
        SCAN_SPAN=$(timerSpan "${name}_SCAN")
        SCAN_DONE=$(globGet "${name}_SCAN_DONE")
        [ "${SCAN_DONE}" == "true" ] && break
        echoInfo "INFO: Waiting for $name scan (PID $PIDX) to finlize, elapsed $SCAN_SPAN/60 seconds ..."
        [[ $SCAN_SPAN -gt 60 ]] && echoErr "ERROR: Timeout failed to scan $name container, see error logs '$SCAN_LOGS/${name}-status.error.log'" && exit 1
        if ! kill -0 "$PIDX" 2>/dev/null ; then
            [ "$(globGet ${name}_SCAN_DONE)" != "true" ] && \
                echoErr "ERROR: Background PID $PIDX failed for the $name container. See error logs: '$SCAN_LOGS/${name}-status.error.log'" && exit 1
        fi
        sleep 1
    done
    set -x

    STATUS_PATH=$(globFile "${name}_SEKAID_STATUS")
    NODE_STATUS=$(globGet ${name}_STATUS)
    if (! $(isFileEmpty "$STATUS_PATH")) ; then
        LATEST_BLOCK=$(jsonQuickParse "latest_block_height" $STATUS_PATH || echo "0") 
        LATEST_BLOCK_TIME=$(jsonParse "sync_info.latest_block_time" $STATUS_PATH || echo "1970-01-01T00:00:00")
        LATEST_BLOCK_TIME=$(date2unix "$LATEST_BLOCK_TIME") 
        CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_PATH || echo "false")
        (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
        (! $(isNaturalNumber "$LATEST_BLOCK_TIME")) && LATEST_BLOCK_TIME=0
        (! $(isBoolean "$CATCHING_UP")) && CATCHING_UP=false

        if [[ "${name,,}" =~ ^(sentry|seed|validator)$ ]] ; then
            NODE_ID=$(jsonQuickParse "id" $STATUS_PATH 2> /dev/null  || echo "false")
            mkdir -p "$INTERX_REFERENCE_DIR"
            ($(isNodeId "$NODE_ID")) && echo "$NODE_ID" > "$INTERX_REFERENCE_DIR/${name,,}_node_id"

            if [[ $LATEST_BLOCK -gt $NEW_LATEST_BLOCK ]] && [[ $LATEST_BLOCK_TIME -gt $NEW_LATEST_BLOCK_TIME ]] ; then
                NEW_LATEST_BLOCK="$LATEST_BLOCK"
                NEW_LATEST_BLOCK_TIME="$LATEST_BLOCK_TIME"
                NEW_LATEST_STATUS="$(tryCat $STATUS_PATH)"
            fi
        fi
    else
        LATEST_BLOCK="0"
        LATEST_BLOCK_TIME="0"
        CATCHING_UP="false"
    fi
    
    [[ $MIN_HEIGHT -gt $LATEST_BLOCK ]] && CATCHING_UP="true"
    ( [ "${NODE_STATUS,,}" == "halted" ] || [ "${NODE_STATUS,,}" == "backing up" ] ) && CATCHING_UP="false"
    [[ "${name,,}" =~ ^(sentry|seed|validator)$ ]] && [ "${CATCHING_UP,,}" == "true" ] && NEW_CATCHING_UP="true"
    
    
    echoInfo "INFO: Saving status props..."
    PREVIOUS_BLOCK=$(globGet "${name}_BLOCK")
    globSet "${name}_BLOCK" "$LATEST_BLOCK"
    globSet "${name}_BLOCK_TIME" "$LATEST_BLOCK_TIME"
    globSet "${name}_SYNCING" "$CATCHING_UP"
done

globSet CONTAINERS_COUNT $CONTAINERS_COUNT
globSet CATCHING_UP $NEW_CATCHING_UP

MIN_HEIGHT=$(globGet MIN_HEIGHT $GLOBAL_COMMON_RO)
LATEST_BLOCK_TIME=$(globGet LATEST_BLOCK_TIME $GLOBAL_COMMON_RO)
LATEST_BLOCK_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT $GLOBAL_COMMON_RO)
if [[ $NEW_LATEST_BLOCK -gt 0 ]] && [[ $NEW_LATEST_BLOCK_TIME -gt 0 ]] && [[ $NEW_LATEST_BLOCK_TIME -gt $LATEST_BLOCK_TIME ]] && [[ $NEW_LATEST_BLOCK -gt $LATEST_BLOCK_HEIGHT ]] ; then
    echoInfo "INFO: Block height chaned to $NEW_LATEST_BLOCK ($NEW_LATEST_BLOCK_TIME)"
    globSet LATEST_BLOCK_TIME "$NEW_LATEST_BLOCK_TIME" $GLOBAL_COMMON_RO
    globSet LATEST_BLOCK_HEIGHT "$NEW_LATEST_BLOCK" $GLOBAL_COMMON_RO
    
    if [[ $NEW_LATEST_BLOCK -gt $MIN_HEIGHT ]] ; then
        globSet MIN_HEIGHT "$NEW_LATEST_BLOCK" $GLOBAL_COMMON_RO
    fi
else
    echoWarn "WARNING: New latest block was NOT found!"
fi
# save latest known status
(! $(isNullOrEmpty "$NEW_LATEST_STATUS")) && echo "$NEW_LATEST_STATUS" | globSet LATEST_STATUS

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS MONITOR                 |"
echoWarn "|  ELAPSED: $(timerSpan MONITOR_CONTAINERS) seconds"
echoWarn "------------------------------------------------"
sleep 1
set -x