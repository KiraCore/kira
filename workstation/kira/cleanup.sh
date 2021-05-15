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

    journalctl --vacuum-time=3d || echoWarn "WARNING: journalctl vacuum failed"
    find "/var/log" -type f -size +2M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate system logs"
    find "/var/log/journal" -type f -size +2M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate journal"

    if [ -d $KIRA_SNAP ]; then
        echoInfo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
        find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echoErr "ERROR: Failed to remove excessive snapshots"
        echoInfo "INFO: Success, all excessive snaps were removed"
    fi

    echoInfo "INFO: Cleanup was finalized, elapsed $(timerSpan) seconds"
    sleep 600
done