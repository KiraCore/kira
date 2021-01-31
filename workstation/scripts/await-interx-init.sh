#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

IS_STARTED="false"
FAUCET_ADDR=""
INTERX_STATUS_CODE=""
CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"

i=0
while [ $i -le 40 ]; do
    i=$((i + 1))

    echoInfo "INFO: Waiting for $CONTAINER_NAME container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME was initialized"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME service to start..."
    INTERX_STATUS_CODE=$(docker exec -t "$CONTAINER_NAME" curl -s -o /dev/null -w '%{http_code}' 0.0.0.0:$DEFAULT_INTERX_PORT/api/status 2>/dev/null | xargs || echo "")

    if [[ "${INTERX_STATUS_CODE}" -ne "200" ]]; then
        sleep 30
        echoWarn "WARNING: $CONTAINER_NAME is not started yet"
        continue
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME faucet to initalize..."
    FAUCET_ADDR=$(docker exec -t "$CONTAINER_NAME" curl 0.0.0.0:$DEFAULT_INTERX_PORT/api/faucet 2>/dev/null | jq -rc '.address' | xargs || echo "")

    if [ -z "${FAUCET_ADDR}" ] || [ "$FAUCET_ADDR" == "null" ] ; then
        sleep 30
        echoWarn "WARNING: $CONTAINER_NAME faucet is initalized yet"
        continue
    else
        echoInfo "INFO: Success, faucet was found"
        break
    fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [[ "$INTERX_STATUS_CODE" -ne "200" ]] || [ -z "$FAUCET_ADDR" ] ; then
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
fi
