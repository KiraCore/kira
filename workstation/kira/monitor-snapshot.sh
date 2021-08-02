#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat

set -x

timerStart SNAP_MONITOR
SNAPSHOT_SCAN_PATH="$KIRA_SCAN/snapshot"
SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"
CONAINER_NAME="snapshot"

while [ "$(globGet IS_SCAN_DONE)" != "true" ] ; do
    echoInfo "INFO: Waiting for monitor scan to finalize run..."
    sleep 10
done

LATEST_BLOCK=$(globGet LATEST_BLOCK)
SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
MAX_SNAPS=$(globGet MAX_SNAPS) && (! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=1
UPDATE_DONE=$(globGet UPDATE_DONE)
UPDATE_FAIL=$(globGet UPDATE_FAIL)

INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA SNAPSHOT SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|       KIRA_SNAP_PATH: $KIRA_SNAP_PATH"
echoWarn "|          SNAP_EXPOSE: $SNAP_EXPOSE"
echoWarn "| INTERX_SNAPSHOT_PATH: $INTERX_SNAPSHOT_PATH"
echoWarn "|         LATEST BLOCK: $LATEST_BLOCK"
echoWarn "|       CONTAINER NAME: $CONAINER_NAME"
echoWarn "|            MAX SNAPS: $MAX_SNAPS"
echoWarn "------------------------------------------------"
set -x

CHECKSUM_TEST="false"
CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONAINER_NAME" || echo "error")

if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ]; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST)"
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ]; then
        echoInfo "INFO: Snap path changed from '$KIRA_SNAP_PATH' into '$KIRA_SNAP_PATH'"
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        if [ "${CONTAINER_EXISTS,,}" == "true"  ] ; then
            timerStart AUTO_BACKUP
            $KIRA_MANAGER/scripts/dump-logs.sh "$CONAINER_NAME" || echoErr "ERROR: Failed to dump $CONAINER_NAME container logs"
            $KIRA_SCRIPTS/container-delete.sh "$CONAINER_NAME" || echoErr "ERROR: Failed to delete $CONAINER_NAME container"
        else
            echoInfo "INFO: Snpashot conainer does NOT exits"
        fi
        CHECKSUM_TEST="true"
    else
        echoInfo "INFO: Latest snap file '$SNAP_LATEST_FILE' was NOT found or 'KIRA_SNAP_PATH' ($KIRA_SNAP_PATH) did NOT changed"
    fi
else
    echoInfo "INFO: Latest snap info file '$SNAP_LATEST' was NOT found or snapshot container is NOT done yet"
fi

if [ "${CHECKSUM_TEST,,}" == "true" ] || ( [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ) ; then
    echoInfo "INFO: Generting sha256 of the snapshot file..."
    KIRA_SNAP_SHA256=$(sha256 "$KIRA_SNAP_PATH")
    CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

if [ -f "$KIRA_SNAP_PATH" ] && ( [ "$KIRA_SNAP_SHA256" != "$INTERX_SNAP_SHA256" ] || [ ! -f "$INTERX_SNAPSHOT_PATH" ] ) ; then
    echoInfo "INFO: Latest snapshot is NOT exposed yet"
    mkdir -p $INTERX_REFERENCE_DIR

    if [ "${SNAP_EXPOSE,,}" == "true" ]; then
        ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
        echoInfo "INFO: Symlink $KIRA_SNAP_PATH => $INTERX_SNAPSHOT_PATH was created"
        CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${SNAP_EXPOSE,,}" == "false" ] && [ -f "$INTERX_SNAPSHOT_PATH" ] ; then
        rm -fv "$INTERX_SNAPSHOT_PATH"
        CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
        echoInfo "INFO: Symlink $KIRA_SNAP_PATH => $INTERX_SNAPSHOT_PATH was removed"
    fi
elif [ -f "$INTERX_SNAPSHOT_PATH" ] && ([ "${SNAP_EXPOSE,,}" == "false" ] || [ -z "$KIRA_SNAP_PATH" ]); then
    echoInfo "INFO: Removing publicly exposed snapshot..."
    rm -f -v $INTERX_SNAPSHOT_PATH
    CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
else
    echoInfo "INFO: No need for snapshot symlink update"
fi

if [ "${UPDATE_DONE,,}" != "true" ] || [ "${UPDATE_FAIL,,}" != "false" ] ; then
    echoInfo "INFO: Snap can't be executed, update is not compleated"
elif [ "${CONTAINER_EXISTS,,}" == "false"  ] ; then
    AUTO_BACKUP_LAST_BLOCK=$(globGet $AUTO_BACKUP_LAST_BLOCK)
    (! $(isNaturalNumber $AUTO_BACKUP_LAST_BLOCK)) && AUTO_BACKUP_LAST_BLOCK=0
    if [ "$(globGet IS_SCAN_DONE)" == "true" ] && [ "$(globGet AUTO_BACKUP)" == "true" ] && [ $LATEST_BLOCK -gt $AUTO_BACKUP_LAST_BLOCK ] && [[ $MAX_SNAPS -gt 0 ]]; then
        TIME_LEFT=$(timerSpan AUTO_BACKUP $(($AUTO_BACKUP_INTERVAL * 3600)))
        if [[ $TIME_LEFT -le 0 ]] ; then
            timerStart AUTO_BACKUP
            globSet AUTO_BACKUP_LAST_BLOCK "$LATEST_BLOCK"
            rm -fv "${SNAPSHOT_SCAN_PATH}-start.log"
            [ -f "$KIRA_SNAP_PATH" ] && SNAP_PATH_TMP=$KIRA_SNAP_PATH || SNAP_PATH_TMP=""
            $KIRA_MANAGER/containers/start-snapshot.sh "$LATEST_BLOCK" "$SNAP_PATH_TMP" &> "${SNAPSHOT_SCAN_PATH}-start.log"
        fi
    else
        echoInfo "INFO: Conditions to execute snapshot were not met or auto snap is not enabled"
    fi
else
    echoInfo "INFO: Snapshot can't be started, container is already running!"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SNAPSHOT MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan SNAP_MONITOR) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 30