#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraclean && journalctl -u kiraclean -f --output cat
set -x

# find largest file: du -a / 2>/dev/null | sort -n -r | head -n 20

while : ; do
    timerStart CLEANUP_SERVICE
    set +e && source "/etc/profile" &>/dev/null && set -e

    MAX_SNAPS=$(globGet MAX_SNAPS) && (! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=1

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| STARTING KIRA CLEANUP SERVICE $KIRA_SETUP_VER"
    echoWarn "|-----------------------------------------------"
    echoWarn "| MAX_SNAPS: $MAX_SNAPS"
    echoWarn "| KIRA_SNAP: $KIRA_SNAP"
    echoWarn "------------------------------------------------"
    set -x

    journalctl --vacuum-time=3d --vacuum-size=32M || echoWarn "WARNING: journalctl vacuum failed"
    find "/var/log" -type f -size +64M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate system logs"

    if [ -d $KIRA_SNAP ]; then
        echoInfo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
        SNAPSHOTS=`ls -S $KIRA_SNAP/*.zip | grep '^d'` || SNAPSHOTS=""

        if [ ! -z "$SNAPSHOTS" ] ; then
            i=0
            for s in $SNAPSHOTS ; do
                [ ! -f $s ] && continue
                i=$((i + 1))

                FILENAME=$(basename $s)
                FILENAME_PREFIX="${NETWORK_NAME}-"
                if [[ "$FILENAME" != $FILENAME_PREFIX* ]]; then
                    echoInfo "INFO: File '$s' does not contain '$FILENAME_PREFIX' prefix, removing..."
                    rm -fv $s || echoErr "ERROR: Failed to remove $s"
                elif [[ $i -gt $MAX_SNAPS ]] ; then
                    sleep 0.5
                    SNAP_STATUS="$KIRA_SNAP/status"
                    SNAP_LATEST="$SNAP_STATUS/latest"
                    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST)"
                    [ "$KIRA_SNAP_PATH" == "$s" ] && echoInfo "INFO: Snap '$s' is latest, will NOT be removed" && continue
                    [ "$SNAP_LATEST_FILE" == "$s" ] && echoInfo "INFO: Snap '$s' might be latest, will NOT be removed" && continue
                    rm -fv $s || echoErr "ERROR: Failed to remove $s"
                else 
                    echoInfo "INFO: Snap '$s' will not be removed, cleanup limit '$MAX_SNAPS' is NOT reached"
                fi
            done | tac
        else
            echoInfo "INFO: No snaps were found in the snap directory, nothing to cleanup"
        fi
    fi

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| FINISHED: KIRA CLEANUP SERVICE               |"
    echoWarn "|  ELAPSED: $(timerSpan CLEANUP_SERVICE) seconds"
    echoWarn "------------------------------------------------"
    set -x
    sleep 600
done