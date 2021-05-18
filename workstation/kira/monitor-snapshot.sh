#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat

set -x

timerStart
SNAPSHOT_SCAN_PATH="$KIRA_SCAN/snapshot"
SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"
UPDATE_DONE_FILE="$KIRA_UPDATE/done"
UPDATE_FAIL_FILE="$KIRA_UPDATE/fail"
CONAINER_NAME="snapshot"

while [ "$(globGet IS_SCAN_DONE)" != "true" ] ; do
    echoInfo "INFO: Waiting for monitor scan to finalize run..."
    sleep 10
done

LATEST_BLOCK=$(globGet LATEST_BLOCK)
SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
MAX_SNAPS=$(globGet MAX_SNAPS) && (! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=1

INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA SNAPSHOT SCAN            |"
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
if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ]; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST)"
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ]; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONAINER_NAME" || echo "error")
        if [ "${CONTAINER_EXISTS,,}" == "true"  ] ; then
            $KIRA_MANAGER/scripts/dump-logs.sh "$CONAINER_NAME" || echoErr "ERROR: Failed to dump $CONAINER_NAME container logs"
            $KIRA_SCRIPTS/container-delete.sh "$CONAINER_NAME" || echoErr "ERROR: Failed to delete $CONAINER_NAME container"
        fi
        CHECKSUM_TEST="true"
    fi
fi

if [ "${CHECKSUM_TEST,,}" == "true" ] || ( [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ) ; then
    echoInfo "INFO: Generting sha256 of the snapshot file..."
    KIRA_SNAP_SHA256=$(sha256 "$KIRA_SNAP_PATH")
    CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

if [ -f "$KIRA_SNAP_PATH" ] && [ "$KIRA_SNAP_SHA256" != "$INTERX_SNAP_SHA256" ] ; then
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
fi

if [ ! -f "$UPDATE_DONE_FILE" ] || [ -f $UPDATE_FAIL_FILE ] ; then
    echoInfo "INFO: Snap can't be executed, update is not compleated"
else
    [ -z "$AUTO_BACKUP_LAST_BLOCK" ] && AUTO_BACKUP_LAST_BLOCK=0
    if [ "$(globGet IS_SCAN_DONE)" == "true" ] && [ "$(globGet AUTO_BACKUP)" == "true" ] && [ $LATEST_BLOCK -gt $AUTO_BACKUP_LAST_BLOCK ] && [[ $MAX_SNAPS -gt 0 ]]; then
        TIME_LEFT=$(timerSpan AUTO_BACKUP $(($AUTO_BACKUP_INTERVAL * 3600)))
        if [[ $TIME_LEFT -le 0 ]] ; then
            rm -fv "${SNAPSHOT_SCAN_PATH}-start.log"
            [ -f "$KIRA_SNAP_PATH" ] && SNAP_PATH_TMP=$KIRA_SNAP_PATH || SNAP_PATH_TMP=""
            $KIRA_MANAGER/containers/start-snapshot.sh "$LATEST_BLOCK" "$SNAP_PATH_TMP" &> "${SNAPSHOT_SCAN_PATH}-start.log"
            timerStart AUTO_BACKUP
            CDHelper text lineswap --insert="AUTO_BACKUP_LAST_BLOCK=$LATEST_BLOCK" --prefix="AUTO_BACKUP_LAST_BLOCK=" --path=$ETC_PROFILE --append-if-found-not=True
        fi
    else
        echoInfo "INFO: Conditions to execute snapshot were not met or auto snap is not enabled"
    fi
fi

sleep 30

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SNAPSHOT MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x