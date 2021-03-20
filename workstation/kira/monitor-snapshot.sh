#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f

set -x

SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"


if [ ! -f $SCAN_DONE ]; then
    echo "INFO: Scan is not done yet, aborting snapshot monitor"
    exit 0
fi

INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"
LATEST_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH || echo "0")

set +x
echo "------------------------------------------------"
echo "|       STARTING KIRA SNAPSHOT SCAN            |"
echo "|-----------------------------------------------"
echo "|       KIRA_SNAP_PATH: $KIRA_SNAP_PATH"
echo "|          SNAP_EXPOSE: $SNAP_EXPOSE"
echo "| INTERX_SNAPSHOT_PATH: $INTERX_SNAPSHOT_PATH"
echo "|         LATEST BLOCK: $LATEST_BLOCK"
echo "------------------------------------------------"
set -x

[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ]; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST)"
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ]; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
fi

if [ -f "$KIRA_SNAP_PATH" ] && [ "${SNAP_EXPOSE,,}" == "true" ]; then
    HASH1=$(sha256sum "$KIRA_SNAP_PATH" | awk '{ print $1 }' || echo "")
    HASH2=$(sha256sum "$INTERX_SNAPSHOT_PATH" | awk '{ print $1 }' || echo "")

    if [ "$HASH1" != "$HASH2" ]; then
        echo "INFO: Latest snapshot is NOT exposed yet"
        mkdir -p $INTERX_REFERENCE_DIR
        cp -f -v -a "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
    else
        echo "INFO: Latest snapshot was already exposed, no need for updates"
    fi
elif [ -f "$INTERX_SNAPSHOT_PATH" ] && ([ "${SNAP_EXPOSE,,}" == "false" ] || [ -z "$KIRA_SNAP_PATH" ]); then
    echo "INFO: Removing publicly exposed snapshot..."
    rm -f -v $INTERX_SNAPSHOT_PATH
fi

if [ -d $KIRA_SNAP ]; then
    echo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
    find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echo "ERROR: Failed to remove excessive snapshots"
    echo "INFO: Success, all excessive snaps were removed"
fi

[ -z "$AUTO_BACKUP_LAST_BLOCK" ] && AUTO_BACKUP_LAST_BLOCK=0
if [ -f $SCAN_DONE ] && [ "$AUTO_BACKUP_ENABLED" == true ] && [ $LATEST_BLOCK -gt $AUTO_BACKUP_LAST_BLOCK ]; then
    ELAPSED_TIME=0
    if [ ! -z "$AUTO_BACKUP_EXECUTED_TIME" ]; then
        ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
    fi
    INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
    if [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] || [ $ELAPSED_TIME -gt $INTERVAL_AS_SECOND ]; then
        AUTO_BACKUP_EXECUTED_TIME=$(date -u +%s)
        rm -fv $SCAN_DONE
        [ -f $KIRA_SNAP_PATH ] SNAP_PATH_TMP=$KIRA_SNAP_PATH || SNAP_PATH_TMP=""
        $KIRA_MANAGER/containers/start-snapshot.sh "$LATEST_BLOCK" "$SNAP_PATH_TMP"
        CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=$AUTO_BACKUP_EXECUTED_TIME" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="AUTO_BACKUP_LAST_BLOCK=$LATEST_BLOCK" --prefix="AUTO_BACKUP_LAST_BLOCK=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
fi

echo "INFO: Finished kira snapshot scann"
