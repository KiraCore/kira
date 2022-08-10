#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraclean && journalctl -u kiraclean -f --output cat
set -x

# find largest file: du -a / 2>/dev/null | sort -n -r | head -n 20
# increase disk space (AWS): growpart /dev/nvme0n1 1 && resize2fs /dev/root

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
    find "$KIRA_LOGS" -type f -size +1M -exec truncate --size=1k {} + || echoWarn "WARNING: Failed to truncate kira logs"

    CONTAINERS=$(timeout 60 docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo "")
    for name in $CONTAINERS; do
        echoInfo "INFO: Cleaning '$name' container...."
        COMMON_PATH="$DOCKER_COMMON/$name"
        COMMON_LOGS="$COMMON_PATH/logs"
        find "$COMMON_LOGS" -type f -size +5M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate container logs"
    done

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| FINISHED: KIRA CLEANUP SERVICE               |"
    echoWarn "|  ELAPSED: $(timerSpan CLEANUP_SERVICE) seconds"
    echoWarn "------------------------------------------------"
    set -x
    sleep 600
done