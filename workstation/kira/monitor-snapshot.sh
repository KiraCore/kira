#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat $KIRA_SCAN/snapshot.log
# cat $KIRA_DUMP/kirascan/snapshot.log
set -x

timerStart SNAP_MONITOR

SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)
CONTAINER_NAME=$(globGet SNAPSHOT_TARGET)
SNAPSHOT_KEEP_OLD=$(globGet SNAPSHOT_KEEP_OLD)
LATEST_BLOCK_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO")
CONTAINER_BLOCK_HEIGHT=$(globGet "${CONTAINER_NAME}_BLOCK") 
IS_SYNCING=$(globGet "${CONTAINER_NAME}_SYNCING")
SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.tar"
(! $(isNaturalNumber $LATEST_BLOCK_HEIGHT)) && LATEST_BLOCK_HEIGHT=0
(! $(isNaturalNumber $CONTAINER_BLOCK_HEIGHT)) && CONTAINER_BLOCK_HEIGHT=0

COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"
SNAPSHOT_UNHALT=$(globGet SNAPSHOT_UNHALT)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA SNAPSHOT SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|      SNAPSHOT SCAN PID: $(globGet SNAPSHOT_SCAN_PID)"
echoWarn "|         KIRA_SNAP_PATH: $KIRA_SNAP_PATH"
echoWarn "|        SNAPSHOT TARGET: $CONTAINER_NAME"
echoWarn "|       CONTAINER UNHALT: $SNAPSHOT_UNHALT"
echoWarn "|            SNAP EXPOSE: $SNAP_EXPOSE"
echoWarn "|           BLOCK HEIGHT: $LATEST_BLOCK_HEIGHT"
echoWarn "| CONTAINER BLOCK HEIGHT: $CONTAINER_BLOCK_HEIGHT"
echoWarn "|             IS SYNCING: $IS_SYNCING"
echoWarn "|     SNAPSHOT REQUESTED: $SNAPSHOT_EXECUTE"
echoWarn "|         KEEP OLD SNAPS: $SNAPSHOT_KEEP_OLD"
echoWarn "------------------------------------------------"
set -x

if [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ; then
    echoInfo "INFO: Updating snpashot '$KIRA_SNAP_PATH' checksum..."
    KIRA_SNAP_SHA256=$(sha256 "$KIRA_SNAP_PATH")
    setGlobEnv KIRA_SNAP_SHA256 "$KIRA_SNAP_SHA256"
    echoInfo "SUCCESS: New checksum calculated!" && sleep 10 && exit 0
fi

($(isNullOrWhitespaces $CONTAINER_NAME)) && echoErr "ERROR: Target container '$CONTAINER_NAME' was NOT defined" && sleep 10 && exit 1
CONTAINER_EXISTS=$($KIRA_COMMON/container-exists.sh "$CONTAINER_NAME" || echo "error")
sleep 15

[ "${CONTAINER_EXISTS,,}" != "true" ] && echoErr "ERROR: Target container '$CONTAINER_NAME' does NOT exists" && sleep 10 && exit 1
[ "$(globGet HALT_TASK $GLOBAL_COMMON)" != "true" ] && [ "${IS_SYNCING,,}" == "true" ] && echoErr "ERROR: Target container '$CONTAINER_NAME' is NOT halted and is still catching up!" && sleep 10 && exit 1
[ "${SNAPSHOT_EXECUTE,,}" != "true" ] && echoErr "ERROR: Snapshoot was not requested and will not be processed, aborting..." && sleep 10 && exit 1

[ $LATEST_BLOCK_HEIGHT -lt $CONTAINER_BLOCK_HEIGHT ] && LATEST_BLOCK_HEIGHT=$CONTAINER_BLOCK_HEIGHT

echoInfo "INFO: Restarting '$CONTAINER_NAME' container and ensuring all processes are killed."
$KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "false"

CONTAINER_EXISTS=$($KIRA_COMMON/container-exists.sh "$CONTAINER_NAME" || echo "error")
sleep 15
[ "${CONTAINER_EXISTS,,}" != "true" ] && echoErr "ERROR: Target container '$CONTAINER_NAME' does NOT exists" && sleep 10 && exit 1

SNAP_FILENAME="${NETWORK_NAME}-${LATEST_BLOCK_HEIGHT}-$(date -u +%s).tar"
KIRA_SNAP_PATH="$KIRA_SNAP/$SNAP_FILENAME"

if [ "${SNAPSHOT_KEEP_OLD,,}" == "true" ] ; then
    echoInfo "INFO: Old snapshots will NOT be persisted"
    rm -fv $KIRA_SNAP_PATH
    rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"
else
    echoInfo "INFO: Wiping all snapshoots from the '$KIRA_SNAP' directory..."
    rm -fv $KIRA_SNAP/*.tar || echoErr "ERROR: Failed to wipe *.tar files from '$KIRA_SNAP' directory"
    rm -fv $KIRA_SNAP/*.zip || echoErr "ERROR: Failed to wipe *.zip files from '$KIRA_SNAP' directory"
    rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"
fi

docker exec -i $CONTAINER_NAME /bin/bash -c ". /etc/profile && \$COMMON_DIR/snapshot.sh \"$SNAP_FILENAME\"" && SUCCESS="true" || SUCCESS="false"

if [ ! -f "$KIRA_SNAP_PATH" ] || [ "${SUCCESS,,}" != "true" ] ; then
    echoErr "ERROR: Failed to create snapshoot file '$KIRA_SNAP_PATH'"
    rm -fv $KIRA_SNAP_PATH || echoErr "ERROR: Failed to remove corrupted snapshot."
    rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"
    rm -fv $DOCKER_COMMON_RO/snap.* || echoErr "ERROR: Failed to wipe snap.* files from '$DOCKER_COMMON_RO' directory"
    sleep 30
else
    echoInfo "INFO: Success, new snapshot '$KIRA_SNAP_PATH' was created"
    setGlobEnv KIRA_SNAP_SHA256 ""
    setGlobEnv KIRA_SNAP_PATH "$KIRA_SNAP_PATH"

    if [ "${SNAP_EXPOSE,,}" == "true" ]; then
        echoInfo "INFO: Exposing snapshoot via INTERX"
        ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
    else
        echoInfo "INFO: No need to expose snapshoot"
    fi
fi

globSet SNAPSHOT_EXECUTE "false"
globSet SNAPSHOT_TARGET ""

if [ "${SNAPSHOT_UNHALT,,}" == "true" ] ; then
    echoInfo "INFO: Restarting and unhalting '$CONTAINER_NAME' container..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "true"
else
    echoInfo "INFO: No need to unhalt '$CONTAINER_NAME' container, container was requested to remain stopped"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SNAPSHOT MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan SNAP_MONITOR) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 30