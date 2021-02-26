#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

echo "INFO: Started kira snapshot scann"

SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

if [ ! -f $SCAN_DONE ] ; then
    echo "INFO: Scan is not done yet, aborting snapshot monitor"
    exit 0
fi

[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ] ; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST)" 
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ] ; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
fi

INTERX_REDERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_SNAPSHOT_PATH="$INTERX_REDERENCE_DIR/snapshot.zip"
if [ -f "$KIRA_SNAP_PATH" ] && [ "${SNAP_EXPOSE,,}" == "true" ] ; then
    HASH1=$(sha256sum "$KIRA_SNAP_PATH" | awk '{ print $1 }' || echo "")
    HASH2=$(sha256sum "$INTERX_SNAPSHOT_PATH" | awk '{ print $1 }' || echo "")

    if [ "$HASH1" != "$HASH2" ] ; then
        echo "INFO: Latest snapshot is NOT exposed yet"
        mkdir -p $INTERX_REDERENCE_DIR
        cp -f -v -a "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
    else
        echo "INFO: Latest snapshot was already exposed, no need for updates"
    fi
elif [ -f "$INTERX_SNAPSHOT_PATH" ] && ( [ "${SNAP_EXPOSE,,}" == "false" ] || [ -z "$KIRA_SNAP_PATH" ] ) ; then
    echo "INFO: Removing publicly exposed snapshot..."
    rm -f -v $INTERX_SNAPSHOT_PATH
fi

if [ -d $KIRA_SNAP ] ; then
    echo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
    find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echo "ERROR: Faile dto remove excessive snapshots"
    echo "INFO: Success, all excessive snaps were removed"
fi

echo "INFO: Finished kira snapshot scann"
