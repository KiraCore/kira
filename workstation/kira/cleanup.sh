#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraclean && journalctl -u kiraclean -f --output cat
set -x

# find largest file: du -a / 2>/dev/null | sort -n -r | head -n 20

timerStart
echoInfo "INFO: Started kira cleanup service $KIRA_SETUP_VER"

while : ; do
    set +e && source "/etc/profile" &>/dev/null && set -e

    MAX_SNAPS=$(globGet MAX_SNAPS) && (! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=1

    journalctl --vacuum-time=2d || echoWarn "WARNING: journalctl vacuum failed"
    find "/var/log" -type f -size +4M -exec truncate --size=2M {} + || echoWarn "WARNING: Failed to truncate system logs"
    find "/var/log/journal" -type f -size +16M -exec truncate --size=4M {} + || echoWarn "WARNING: Failed to truncate journal"

    if [ -d $KIRA_SNAP ]; then
        echoInfo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
        SNAPSHOTS=`ls -S $KIRA_SNAP/*.zip | grep -v '^d'` || SNAPSHOTS=""
        if [ ! -z "$SNAPSHOTS" ] ; then
            i=0
            SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST)"
            for s in $SNAPSHOTS ; do
                [ ! -f $s ] && continue
                i=$((i + 1))
                if [[ $i -gt $MAX_SNAPS ]] ; then
                    [ "$KIRA_SNAP_PATH" == "$s" ] && echoInfo "INFO: Snap '$s' is latest, will NOT be removed" && continue
                    [ "$SNAP_LATEST_FILE" == "$s" ] && echoInfo "INFO: Snap '$s' might be latest, will NOT be removed" && continue
                    rm -fv $s || echoErr "ERROR: Failed to remove $s"
                else 
                    echoInfo "INFO: Snap '$s' will not be removed, cleanup limit '$MAX_SNAPS' is NOT reached"
                fi
            done
        else
            echoInfo "INFO: No snaps were found in the snap directory, nothing to cleanup"
        fi
    fi

    echoInfo "INFO: Cleanup was finalized, elapsed $(timerSpan) seconds"
    sleep 600
done