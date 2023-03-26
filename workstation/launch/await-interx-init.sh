#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/launch/await-interx-init.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

IS_STARTED="false"
INTERX_STATUS_CODE=""
CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
APP_HOME="$DOCKER_HOME/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
TIMER_NAME="${CONTAINER_NAME}_INIT"
TIMEOUT=1800

CUSTOM_INTERX_PORT=$(globGet CUSTOM_INTERX_PORT)
DEFAULT_INTERX_PORT=$(globGet DEFAULT_INTERX_PORT)

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING $CONTAINER_NAME INIT $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| COMMON DIR: $COMMON_PATH"
echoWarn "|    TIMEOUT: $TIMEOUT seconds"
echoWarn "|-------------------------------------------------"
set -x

globDel "${CONTAINER_NAME}_STATUS" "${CONTAINER_NAME}_EXISTS"
timerStart $TIMER_NAME

systemctl restart kirascan || echoWarn "WARNING: Could NOT restart kira scan service"

while [[ $(timerSpan $TIMER_NAME) -lt $TIMEOUT ]] ; do

    echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
    if [ "$(globGet ${CONTAINER_NAME}_EXISTS)" != "true" ]; then
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
    else echoInfo "INFO: Success, container $CONTAINER_NAME was found" ; fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME was initialized" ; fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME service to start..."
    INTERX_STATUS_CODE=$(docker exec -t "$CONTAINER_NAME" curl -s -o /dev/null -w '%{http_code}' 0.0.0.0:$DEFAULT_INTERX_PORT/api/metadata 2>/dev/null | xargs || echo -n "")

    if [[ "${INTERX_STATUS_CODE}" -ne "200" ]]; then
        sleep 30
        echoWarn "WARNING: $CONTAINER_NAME is not started yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        continue
    fi
    
    break
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_COMMON/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 200 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [[ "$INTERX_STATUS_CODE" -ne "200" ]] || [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
    echoErr "ERROR: $CONTAINER_NAME did NOT acheive running status"
    exit 1
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: $CONTAINER_NAME INIT"
echoWarn "|  ELAPSED: $(timerSpan $TIMER_NAME) seconds"
echoWarn "------------------------------------------------"
set -x