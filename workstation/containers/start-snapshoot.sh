#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshoot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1

START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
SNAP_STATUS="$SCAN_DIR/snap"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_SUCCESS="$SNAP_STATUS/success"
SNAP_PROGRESS="$SNAP_STATUS/progress"

SNAP_FILENAME="${SENTRY_NETWORK}-$(date -u +%s).zip"

SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

SOURCE_DIR="/root/.simapp/data"
SOURCE_FILE="/snap/$SNAP_FILENAME"

rm -fvr "$SNAP_STATUS" "$SNAP_FILE" "$SOURCE_FILE"
mkdir -p "$SNAP_STATUS" "$KIRA_SNAP"
echo "false" > $SNAP_DONE
echo "false" > $SNAP_SUCCESS
echo "0" > $SNAP_PROGRESS

CONTAINER_NAME="snapshoot"
[ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="0"

SENTRY_STATUS=$(docker exec -i "sentry" sekaid status 2> /dev/null | jq -r '.' 2> /dev/null || echo "")
SENTRY_CATCHING_UP=$(echo $SENTRY_STATUS | jq -r '.sync_info.catching_up' 2> /dev/null || echo "") && [ -z "$SENTRY_CATCHING_UP" ] && SENTRY_CATCHING_UP="true"
SENTRY_NETWORK=$(echo $SENTRY_STATUS | jq -r '.node_info.network' 2> /dev/null || echo "")

if [ "${SENTRY_CATCHING_UP,,}" != "false" ] || [ -z "$SENTRY_NETWORK" ] ; then
    echo "INFO: Failed to snapshoot state, public sentry is still catching up..."
    exit 1
fi

if [ $MAX_HEIGHT -le 0 ] ; then
    SENTRY_BLOCK=$(echo $SENTRY_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") && [ -z "$SENTRY_BLOCK" ] && SENTRY_BLOCK="0"
    MAX_HEIGHT=$SENTRY_BLOCK
fi

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
cp -a $SNAP_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json
set -e

echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|     NETWORK: $KIRA_SENTRY_NETWORK"
echo "|    HOSTNAME: $KIRA_SNAPSHOOT_DNS"
echo "| SYNC HEIGHT: $MAX_HEIGHT" 
echo "|   SNAP FILE: $SNAP_FILE"
echo "|  SOURCE DIR: $SOURCE_DIR"
echo "------------------------------------------------"
set -x

echo "INFO: Cleaning up snapshoot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up $CONTAINER_NAME config files..."
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="seed = \"$SENTRY_SEED\"" --prefix="seed =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="persistent_peers = \"tcp://$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="unconditional_peer_ids = \"$SENTRY_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$DOCKER_COMMON/sentry
# Set true for strict address routability rules & Set false for private or local networks
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$DOCKER_COMMON/sentry # fastsync
CDHelper text lineswap --insert="seed_mode = \"false\"" --prefix="seed_mode =" --path=$DOCKER_COMMON/sentry # pex must be true
CDHelper text lineswap --insert="cors_allowed_origins = [ \"*\" ]" --prefix="cors_allowed_origins =" --path=$DOCKER_COMMON/sentry 

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --hostname $KIRA_SNAPSHOOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -v $DOCKER_COMMON/sentry:/common \
    -v $KIRA_SNAP:/snap \
    sentry:latest

echo "INFO: Waiting for $CONTAINER_NAME node to start..."

CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOOT_NODE_ID" || CONTAINER_CREATED="false"

SUCCESS=false
if [ "${CONTAINER_CREATED,,}" == "true" ] ; 
    SUCCESS=true
    echo "INFO: Success container is up and running, waiting for node to sync..."
    set +x
    while : ; do
        SNAP_STATUS=$(docker exec -i "$CONTAINER_NAME" sekaid status 2> /dev/null | jq -r '.' 2> /dev/null || echo "")
        SNAP_BLOCK=$(echo $SNAP_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") && [ -z "$SNAP_BLOCK" ] && SNAP_BLOCK="0"

        if [ $SNAP_BLOCK -lt $SENTRY_BLOCK ] ; then
            echo "INFO: Waiting for snapshoot node to sync  $SNAP_BLOCK/$SENTRY_BLOCK..."
            echo "scale=2; $SNAP_BLOCK / $SENTRY_BLOCK" | bc > $SNAP_PROGRESS
        if [ $SNAP_BLOCK -eg $SENTRY_BLOCK ] ; then
            echo "INFO: Success, target height reached, the node was synced!"
            break
        fi
        sleep 30
    done
fi

if [ "${SUCCESS,,}" != "true" ] ; then
    echo "INFO: Please wait, compressing data files..."
    docker exec -i "sentry" zip -r "$SOURCE_FILE" "$SOURCE_DIR"
    CHECKSUM_SOURCE=$(echo $(docker exec -i "sentry" sha256sum "$SOURCE_DIR.zip") | awk '{ print $1 }')
    CHECKSUM_DESTINATION=$(sha256sum $SNAP_FILE | awk '{ print $1 }')

    if [ "$CHECKSUM_SOURCE" == "$CHECKSUM_DESTINATION" ] ; then 
        echo "INFO: Success, snapshoot file was created & checksum match!"
    else
        echo "ERROR: Failed to snapshoot data, expected checksum '$CHECKSUM_SOURCE', but got '$CHECKSUM_DESTINATION'"
        rm -fv "$SNAP_FILE"
        SUCCESS="false"
    fi
fi

echo "$SUCCESS" > $SNAP_SUCCESS
echo "true" > $SNAP_DONE

echo "INFO: Cleaning up snapshoot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

set +x

if [ "${SUCCESS,,}" != "true" ] ; then
    echo "INFO: Failure, snapshoot was not created elapsed $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
else
    echo "INFO: Snapshoot file name: $SNAP_FILE"
    echo "INFO: Snapshoot checksum: $CHECKSUM"
    echo "INFO: Success, snapshoot was created, elapsed $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
fi

