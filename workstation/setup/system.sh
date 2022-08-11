
#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/system.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Setting up system pre-requisites..."

LIMITS_CFG="/etc/security/limits.conf"
JOURNAL_CFG="/etc/systemd/journald.conf"
WAKEUP_DIR="/usr/lib/pm-utils/sleep.d"
WAKEUP_SCRIPT="${WAKEUP_DIR}/99ZZZ_KiraWakeup.sh"

mkdir -p $KIRA_LOGS $WAKEUP_DIR
touch $KIRA_LOGS/wakeup.log

setLastLineByPrefixOrAppend "* hard nofile" "* hard nofile 999999" $LIMITS_CFG
setLastLineByPrefixOrAppend "* soft nofile" "* soft nofile 999999" $LIMITS_CFG

setVar "SystemMaxUse" "512M" $JOURNAL_CFG
setVar "SystemMaxFileSize" "8M" $JOURNAL_CFG

WAKEUP_ENTRY="#!/bin/sh
exec 1> $KIRA_LOGS/wakeup.log 2>&1
set -x
case \"\$1\" in
    resume)
        rm -fvr $KIRA_SCAN/status || echo \"ERROR: Failed to remove old scan data\"
        systemctl daemon-reload || echo \"ERROR: Failed daemon reload\"
        systemctl start firewalld || echo \"ERROR: Failed firewall restart\"
        firewall-cmd --complete-reload || echo \"ERROR: Failed firewall reload\"
        systemctl restart docker || echo \"ERROR: Failed to restart docker\"
        systemctl restart kirascan || echo \"WARNING: Could NOT restart kira scan service\"
        systemctl restart kiraup || echo \"WARNING: Could NOT restart kira update service\"
        systemctl restart kiraclean || echo \"WARNING: Could NOT restart kira cleanup service\"
esac
exit 0"

cat > $WAKEUP_SCRIPT <<< $WAKEUP_ENTRY
chmod 555 $WAKEUP_SCRIPT $KIRA_LOGS/wakeup.log

echoInfo "INFO: Your system has all pre-requisites set"