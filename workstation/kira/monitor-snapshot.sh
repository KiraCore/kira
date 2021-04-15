#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat

set -x

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
SNAPSHOT_SCAN_PATH="$SCAN_DIR/snapshot"
SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"


if [ ! -f $SCAN_DONE ]; then
    echo "INFO: Scan is not done yet, aborting snapshot monitor"
    sleep 60
    exit 0
fi

INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"
LATEST_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH || echo "0")
DOCKER_SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.zip"

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
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST)"
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ]; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        CHECKSUM_TEST="true"
    fi
fi

if [ "${CHECKSUM_TEST,,}" == "true" ] || ( [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ) ; then
    echo "INFO: Generting sha256 of the snapshot file..."
    KIRA_SNAP_SHA256=$(sha256sum "$KIRA_SNAP_PATH" | awk '{ print $1 }' || echo -n "")
    CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

if [ -f "$KIRA_SNAP_PATH" ] && [ "${SNAP_EXPOSE,,}" == "true" ] && [ "$KIRA_SNAP_SHA256" != "$INTERX_SNAP_SHA256" ] ; then
    if [ "$KIRA_SNAP_SHA256" != "$INTERX_SNAP_SHA256" ]; then
        echo "INFO: Latest snapshot is NOT exposed yet"
        mkdir -p $INTERX_REFERENCE_DIR
        cp -f -v -a "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
        cp -f -v -a "$KIRA_SNAP_PATH" "$DOCKER_SNAP_DESTINATION"
        CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"$KIRA_SNAP_SHA256\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
    else
        echo "INFO: Latest snapshot was already exposed, no need for updates"
    fi
elif [ -f "$INTERX_SNAPSHOT_PATH" ] && ([ "${SNAP_EXPOSE,,}" == "false" ] || [ -z "$KIRA_SNAP_PATH" ]); then
    echo "INFO: Removing publicly exposed snapshot..."
    rm -f -v $INTERX_SNAPSHOT_PATH
    CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

if [ -d $KIRA_SNAP ]; then
    echo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
    find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echo "ERROR: Failed to remove excessive snapshots"
    echo "INFO: Success, all excessive snaps were removed"
fi

[ -z "$AUTO_BACKUP_LAST_BLOCK" ] && AUTO_BACKUP_LAST_BLOCK=0
if [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] ; then
    echo "INFO: Backup was never scheaduled before, it will be set to be executed within 1 interval from current time"
    CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=\"$(date -u +%s)\"" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
elif [ -f $SCAN_DONE ] && [ "${AUTO_BACKUP_ENABLED,,}" == "true" ] && [ $LATEST_BLOCK -gt $AUTO_BACKUP_LAST_BLOCK ]; then
    ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
    INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
    if [[ $ELAPSED_TIME -gt $INTERVAL_AS_SECOND ]]; then
        rm -fv $SCAN_DONE
        [ -f "$KIRA_SNAP_PATH" ] && SNAP_PATH_TMP=$KIRA_SNAP_PATH || SNAP_PATH_TMP=""
        $KIRA_MANAGER/containers/start-snapshot.sh "$LATEST_BLOCK" "$SNAP_PATH_TMP" &> "${SNAPSHOT_SCAN_PATH}-start.log"
        CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=\"$(date -u +%s)\"" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="AUTO_BACKUP_LAST_BLOCK=$LATEST_BLOCK" --prefix="AUTO_BACKUP_LAST_BLOCK=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
else
    echo "INFO: Conditions to execute snapshot were not met or auto snap is not enabled"
fi

sleep 30

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SNAPSHOT MONITOR                   |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x