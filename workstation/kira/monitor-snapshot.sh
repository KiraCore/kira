#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat $KIRA_SCAN/snapshot.log
set -x

timerStart SNAP_MONITOR

SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)
CONTAINER_NAME=$(globGet SNAPSHOT_TARGET)
SNAPSHOT_KEEP_OLD=$(globGet SNAPSHOT_KEEP_OLD)
LATEST_BLOCK_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT) && (! $(isNaturalNumber $LATEST_BLOCK_HEIGHT)) && LATEST_BLOCK_HEIGHT=0
CONTAINER_BLOCK_HEIGHT=$(globGet "${CONTAINER_NAME}_BLOCK") && (! $(isNaturalNumber $CONTAINER_BLOCK_HEIGHT)) && CONTAINER_BLOCK_HEIGHT=0
SNAPSHOT_UNHALT=$(globGet SNAPSHOT_UNHALT)
SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"


set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA SNAPSHOT SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|         KIRA_SNAP_PATH: $KIRA_SNAP_PATH"
echoWarn "|         CONTAINER NAME: $CONTAINER_NAME"
echoWarn "|       CONTAINER UNHALT: $SNAPSHOT_UNHALT"
echoWarn "|            SNAP EXPOSE: $SNAP_EXPOSE"
echoWarn "|           BLOCK HEIGHT: $LATEST_BLOCK_HEIGHT"
echoWarn "| CONTAINER BLOCK HEIGHT: $CONTAINER_BLOCK_HEIGHT"
echoWarn "|     SNAPSHOT REQUESTED: $SNAPSHOT_EXECUTE"
echoWarn "|         KEEP OLD SNAPS: $SNAPSHOT_KEEP_OLD"
echoWarn "------------------------------------------------"
set -x

($(isNullOrWhitespace $CONTAINER_NAME)) && echoErr "ERROR: Target container '$CONTAINER_NAME' was NOT defined" && sleep 10 && exit 1
CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
sleep 15

[ "${CONTAINER_EXISTS,,}" != "true" ] && echoErr "ERROR: Target container '$CONTAINER_NAME' does NOT exists" && sleep 10 && exit 1
[ "${SNAPSHOT_EXECUTE,,}" != "true" ] && echoErr "ERROR: Snapshoot was not requested and will not be processed, aborting..." && sleep 10 && exit 1

[ $LATEST_BLOCK_HEIGHT -lt $CONTAINER_BLOCK_HEIGHT ] && LATEST_BLOCK_HEIGHT=$CONTAINER_BLOCK_HEIGHT

echoInfo "INFO: Restarting '$CONTAINER_NAME' container and ensuring all processes are killed."
$KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "false"

CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
sleep 15
[ "${CONTAINER_EXISTS,,}" != "true" ] && echoErr "ERROR: Target container '$CONTAINER_NAME' does NOT exists" && sleep 10 && exit 1

SNAP_FILENAME="${NETWORK_NAME}-${LATEST_BLOCK_HEIGHT}-$(date -u +%s).zip"
KIRA_SNAP_PATH="$KIRA_SNAP/$SNAP_FILENAME"

if [ "${SNAPSHOT_KEEP_OLD,,}" == "true" ] ; then
    echoInfo "INFO: Old snapshots will NOT be persisted"
    rm -fv $KIRA_SNAP_PATH
else
    echoInfo "INFO: Wiping all snapshoots from the '$KIRA_SNAP' directory..."
    rm -fv $KIRA_SNAP/*.zip
fi

docker exec -i $CONTAINER_NAME /bin/bash -c ". /etc/profile && \$SELF_CONTAINER/snapshot.sh \"$SNAP_FILENAME\""

[ ! -f "$KIRA_SNAP_PATH" ] && echoErr "ERROR: Failed to create snapshoot file '$KIRA_SNAP_PATH'" && sleep 10 && exit 1

KIRA_SNAP_SHA256=$(sha256 "$KIRA_SNAP_PATH")
CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

if [ "${SNAP_EXPOSE,,}" == "true" ]; then
    echoInfo "INFO: Exposing snapshoot via INTERX"
    ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
else
    echoInfo "INFO: No need to expose snapshoot"
fi

if [ "${SNAPSHOT_UNHALT,,}" == "true" ] ; then
    echoInfo "INFO: Restarting and unhalting '$CONTAINER_NAME' container..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "true"
else
    echoInfo "INFO: No need to unhalt '$CONTAINER_NAME' container, container was requested to remain stopped"
fi

globSet SNAPSHOT_EXECUTE "false"
globSet SNAPSHOT_TARGET ""

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SNAPSHOT MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan SNAP_MONITOR) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 30