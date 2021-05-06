#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

timerStart
echoInfo "INFO: Started kira cleanup service $KIRA_SETUP_VER"

while : ; do
    journalctl --vacuum-time=3d || echoWarn "WARNING: journalctl vacuum failed"
    find "/val/log" -type f -size +8M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate system logs"
    find "/var/log/journal" -type f -size +512k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate journal"




    echoInfo "INFO: Cleanup was finalized, elapsed $(timerSpan) seconds"
    sleep 600
done