#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat

set -x

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DONE="$KIRA_SCAN/done"
LATEST_BLOCK_SCAN_PATH="$KIRA_SCAN/latest_block"
SNAPSHOT_SCAN_PATH="$KIRA_SCAN/snapshot"
SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"
UPDATE_DONE_FILE="$KIRA_UPDATE/done"
UPDATE_FAIL_FILE="$KIRA_UPDATE/fail"

while [ ! -f $SCAN_DONE ] ; do
    echoInfo "INFO: Waiting for monitor scan to finalize run..."
    sleep 10
done

LATEST_BLOCK=$(tryCat $LATEST_BLOCK_SCAN_PATH "0")

INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA SNAPSHOT SCAN            |"
echoWarn "|-----------------------------------------------"
echoWarn "|       KIRA_SNAP_PATH: $KIRA_SNAP_PATH"
echoWarn "|          SNAP_EXPOSE: $SNAP_EXPOSE"
echoWarn "| INTERX_SNAPSHOT_PATH: $INTERX_SNAPSHOT_PATH"
echoWarn "|         LATEST BLOCK: $LATEST_BLOCK"
echoWarn "------------------------------------------------"
set -x

(! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=2

CHECKSUM_TEST="false"
if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ]; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST)"
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ]; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        $KIRA_SCRIPTS/container-delete.sh "snapshot" || echoErrr "ERROR: Failed to delete snapshot container"
        CHECKSUM_TEST="true"
    fi
fi

if [ "${CHECKSUM_TEST,,}" == "true" ] || ( [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ) ; then
    echoInfo "INFO: Generting sha256 of the snapshot file..."
    KIRA_SNAP_SHA256=$(sha256sum "$KIRA_SNAP_PATH" | awk '{ print $1 }' || echo -n "")
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

if [ -d $KIRA_SNAP ]; then
    echoInfo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
    find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echoErr "ERROR: Failed to remove excessive snapshots"
    echoInfo "INFO: Success, all excessive snaps were removed"
fi

if [ ! -f "$UPDATE_DONE_FILE" ] || [ -f $UPDATE_FAIL_FILE ] ; then
    echoInfo "INFO: Snap can't be executed, update is not compleated"
else
    [ -z "$AUTO_BACKUP_LAST_BLOCK" ] && AUTO_BACKUP_LAST_BLOCK=0
    if [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] ; then
        echoInfo "INFO: Backup was never scheaduled before, it will be set to be executed within 1 interval from current time"
        CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=\"$(date -u +%s)\"" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ -f $SCAN_DONE ] && [ "${AUTO_BACKUP_ENABLED,,}" == "true" ] && [ $LATEST_BLOCK -gt $AUTO_BACKUP_LAST_BLOCK ] && [[ $MAX_SNAPS -gt 0 ]]; then
        ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
        INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
        if [[ $ELAPSED_TIME -gt $INTERVAL_AS_SECOND ]] ; then
            rm -fv $SCAN_DONE "${SNAPSHOT_SCAN_PATH}-start.log"
            [ -f "$KIRA_SNAP_PATH" ] && SNAP_PATH_TMP=$KIRA_SNAP_PATH || SNAP_PATH_TMP=""
            $KIRA_MANAGER/containers/start-snapshot.sh "$LATEST_BLOCK" "$SNAP_PATH_TMP" &> "${SNAPSHOT_SCAN_PATH}-start.log"
            CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=\"$(date -u +%s)\"" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
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
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x