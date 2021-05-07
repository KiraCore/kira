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
    journalctl --vacuum-time=3d || echoWarn "WARNING: journalctl vacuum failed"
    find "/var/log" -type f -size +8M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate system logs"
    find "/var/log/journal" -type f -size +512k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate journal"

    echoInfo "INFO: Cleanup was finalized, elapsed $(timerSpan) seconds"
    sleep 600
done