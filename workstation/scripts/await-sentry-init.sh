#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

CONTAINER_NAME=$1
SENTRY_NODE_ID=$2
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
PREVIOUS_HEIGHT=0
HEIGHT=0
STATUS=""

i=0
NODE_ID=""
IS_STARTED="false"
while [ $i -le 40 ]; do
    i=$((i + 1))

    echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echoInfo "INFO: Success, container $CONTAINER_NAME was found"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echoInfo "INFO: Success, container was initialized"
    fi

    echoInfo "INFO: Awaiting node status..."
    STATUS=$(docker exec -i "$CONTAINER_NAME" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "")
    NODE_ID=$(echo "$STATUS" | jq -rc '.NodeInfo.id' 2>/dev/null | xargs || echo "")
    ( [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ) && NODE_ID=$(echo "$STATUS" | jq -rc '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ; then
        sleep 12
        echoWarn "WARNING: Status and Node ID is not available"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container id found: $NODE_ID"
    fi

    echoInfo "INFO: Awaiting first blocks to be synced..."
    HEIGHT=$(echo "$STATUS" | jq -rc '.SyncInfo.latest_block_height' || echo "")
    ( [ -z "${HEIGHT}" ] || [ "${HEIGHT,,}" == "null" ] ) && HEIGHT=$(echo "$STATUS" | jq -rc '.sync_info.latest_block_height' || echo "")
    ( [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ) && HEIGHT=0
    
    if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
        echoWarn "WARNING: New blocks are not beeing synced yet!"
        sleep 10
        PREVIOUS_HEIGHT=$HEIGHT
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks"
        break
    fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 150 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [ "${IS_STARTED,,}" != "true" ] ; then
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
fi

if [ "$NODE_ID" != "$SENTRY_NODE_ID" ] ; then
    echoErr "ERROR: $CONTAINER_NAME Node id check failed!"
    echoErr "ERROR: Expected '$SENTRY_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
fi

if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
    echoErr "ERROR: $CONTAINER_NAME node failed to start catching up new blocks, check node configuration, peers or if seed nodes function correctly."
    exit 1
fi

NETWORK=$(echo $STATUS | jq -rc '.NodeInfo.network' 2> /dev/null || echo "")
( [ -z "${NETWORK}" ] || [ "${NETWORK,,}" == "null" ] ) && NETWORK=$(echo "$STATUS" | jq -rc '.node_info.network' || echo "")
if [ "$NETWORK_NAME" != "$NETWORK" ] ; then
    echoErr "ERROR: Expected network name to be '$NETWORK_NAME' but got '$NETWORK'"
    exit 1
fi

if [ "${EXTERNAL_SYNC,,}" == "true" ] && [ "${CONTAINER_NAME,,}" == "sentry" ] ; then
    echoInfo "INFO: External state synchronisation detected, $CONTAINER_NAME must be fully synced before setup can proceed"
    echoInfo "INFO: Local snapshot must be created before network can be started"

    while : ; do
        echoInfo "INFO: Awaiting node status..."
        STATUS=$(docker exec -i "$CONTAINER_NAME" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "")
        if [ -z "$STATUS" ] || [ "${STATUS,,}" == "null" ] ; then
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"
            echoErr "ERROR: Node failed or status could not be fetched, your netwok connectivity might have been interrupted"
            SELECT="." && while ! [[ "${SELECT,,}" =~ ^(a|c)$ ]] ; do echoNErr "Do you want to [A]bort or [C]ontinue setup?: " && read -d'' -s -n1 ACCEPT && echo ""; done
            [ "${SELECT,,}" == "a" ] && echoWarn "WARINIG: Operation was aborted" && sleep 1 && exit 1
            continue
        fi

        set +x
        SYNCING=$(echo $STATUS | jq -r '.SyncInfo.catching_up' 2> /dev/null || echo "false")
        ( [ -z "$SYNCING" ] || [ "${SYNCING,,}" == "null" ] ) && SYNCING=$(echo $STATUS | jq -r '.sync_info.catching_up' 2> /dev/null || echo "false")
        HEIGHT=$(echo "$STATUS" | jq -rc '.SyncInfo.latest_block_height' || echo "")
        ( [ -z "${HEIGHT}" ] || [ "${HEIGHT,,}" == "null" ] ) && HEIGHT=$(echo "$STATUS" | jq -rc '.sync_info.latest_block_height' || echo "")
        ( [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ) && HEIGHT=0
        set -x

        if [ "${SYNCING,,}" == "false" ] && [ $HEIGHT -ge $VALIDATOR_MIN_HEIGHT ] ; then
            echoInfo "INFO: Node finished catching up."
            break
        fi

        set +x
        echoInfo "INFO: Minimum height: $VALIDATOR_MIN_HEIGHT, current height: $HEIGHT, catching up: $SYNCING"
        echoInfo "INFO: Do NOT close your terminal, waiting for $CONTAINER_NAME to finish catching up..."
        set -x
        sleep 30
    done

    echo "INFO: Halting $CONTAINER_NAME container"
    touch $HALT_FILE
    echo "INFO: Re-starting $CONTAINER_NAME container..."
    $KIRA_SCRIPTS/container-restart.sh $CONTAINER_NAME
    
    echo "INFO: Creating new snapshot..."

    DATA_DIR="$SEKAID_HOME/data"
    LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
    SNAP_STATUS="$KIRA_SNAP/status"
    
    SNAP_FILENAME="${NETWORK_NAME}-$HEIGHT-$(date -u +%s).zip"
    DESTINATION_FILE="$KIRA_SNAP/$SNAP_FILENAME"

    mkdir -p $SNAP_STATUS
    echo "$SNAP_FILENAME" > "$KIRA_SNAP/status/latest"

    docker exec -i "$CONTAINER_NAME" bash -c "cp -v -f $SEKAID_HOME/config/genesis.json $DATA_DIR"
    docker exec -i "$CONTAINER_NAME" bash -c "cd $SEKAID_HOME/data && zip -r -v /snap/$SNAP_FILENAME . *"
    CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$DESTINATION_FILE\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

    echo "INFO: Un-Halting $CONTAINER_NAME container"
    rm -fv $HALT_FILE
    echo "INFO: Re-starting $CONTAINER_NAME container..."
    $KIRA_SCRIPTS/container-restart.sh $CONTAINER_NAME

    echo "INFO: New snapshot was created!"
    CDHelper text lineswap --insert="VALIDATOR_MIN_HEIGHT=\"$HEIGHT\"" --prefix="VALIDATOR_MIN_HEIGHT=" --path=$ETC_PROFILE --append-if-found-not=True
fi

