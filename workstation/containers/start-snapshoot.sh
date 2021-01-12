#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshoot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"

rm -fvr "$SNAP_STATUS"
mkdir -p "$SNAP_STATUS"

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

SNAP_FILENAME="${SENTRY_NETWORK}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

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
echo "------------------------------------------------"
set -x

echo "INFO: Cleaning up snapshoot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up $CONTAINER_NAME config files..."
# * Config sentry/configs/config.toml

COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$COMMON_PATH
CDHelper text lineswap --insert="seed = \"$SENTRY_SEED\"" --prefix="seed =" --path=$COMMON_PATH
CDHelper text lineswap --insert="persistent_peers = \"tcp://$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$COMMON_PATH
CDHelper text lineswap --insert="unconditional_peer_ids = \"$SENTRY_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$COMMON_PATH
# Set true for strict address routability rules & Set false for private or local networks
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$COMMON_PATH
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$COMMON_PATH # fastsync
CDHelper text lineswap --insert="seed_mode = \"false\"" --prefix="seed_mode =" --path=$COMMON_PATH # pex must be true
CDHelper text lineswap --insert="cors_allowed_origins = [ \"*\" ]" --prefix="cors_allowed_origins =" --path=$COMMON_PATH

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --hostname $KIRA_SNAPSHOOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    $CONTAINER_NAME:latest # use sentry image as base

echo "INFO: Waiting for $CONTAINER_NAME node to start..."
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOOT_NODE_ID" || CONTAINER_CREATED="false"

if [ "${CONTAINER_CREATED,,}" != "true" ] ; then
    echo "INFO: Snapshoot failed, '$CONTAINER_NAME' container did not start"
else
    echo "INFO: Success '$CONTAINER_NAME' container was started"
    echo "INFO: Snapshoot destination: $SNAP_FILE"
    echo "INFO: Please await snapshoot container to reach 100% sync status"
fi
