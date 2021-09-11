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

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| STARTING KIRA CLEANUP SERVICE $KIRA_SETUP_VER"
    echoWarn "------------------------------------------------"
    set -x

    journalctl --vacuum-time=3d --vacuum-size=32M || echoWarn "WARNING: journalctl vacuum failed"
    find "/var/log" -type f -size +64M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate system logs"

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| FINISHED: KIRA CLEANUP SERVICE               |"
    echoWarn "|  ELAPSED: $(timerSpan CLEANUP_SERVICE) seconds"
    echoWarn "------------------------------------------------"
    set -x
    sleep 600
done