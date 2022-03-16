
#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/system.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

ESSENTIALS_HASH=$(echo "$KIRAMGR_SCRIPTS-" | md5)
SETUP_CHECK="$KIRA_SETUP/system-4-$ESSENTIALS_HASH" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echoInfo "INFO: Update and Intall system tools and dependencies..."
    apt-get update -y --fix-missing
    apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
        pm-utils

    echoInfo "INFO: Setting up system pre-requisites..."
    CDHelper text lineswap --insert="* hard nofile 999999" --prefix="* hard nofile" --path="/etc/security/limits.conf" --append-if-found-not=True
    CDHelper text lineswap --insert="* soft nofile 999999" --prefix="* soft nofile" --path="/etc/security/limits.conf" --append-if-found-not=True

    STATUS_SCAN_PATH="$KIRA_SCAN/status"

    WAKEUP_ENTRY="#!/bin/sh
case \"\$1\" in
    resume)
        rm -fvr $STATUS_SCAN_PATH || echo \"ERROR: Failed to remove old scan data\"
        systemctl daemon-reload || echo \"ERROR: Failed daemon reload\"
        systemctl start firewalld || echo \"ERROR: Failed firewall restart\"
        firewall-cmd --complete-reload || echo \"ERROR: Failed firewall reload\"
        systemctl restart docker || echo \"ERROR: Failed to restart docker\"
        systemctl restart kirascan || echo \"WARNING: Could NOT restart kira scan service\"
        systemctl restart kiraup || echo \"WARNING: Could NOT restart kira update service\"
        systemctl restart kiraclean || echo \"WARNING: Could NOT restart kira cleanup service\"
esac
exit 0"

    #$KIRAMGR_SCRIPTS/restart-networks.sh \"true\" || echo \"ERROR: Failed to reinitalize networking\"
    #esac
    JOURNAL_CFG="/etc/systemd/journald.conf"
    CDHelper text lineswap --insert="SystemMaxUse=512M" --contains="SystemMaxUse=" --path=$JOURNAL_CFG --append-if-found-not=True
    CDHelper text lineswap --insert="SystemMaxFileSize=8M" --contains="SystemMaxFileSize=" --path=$JOURNAL_CFG --append-if-found-not=True

    mkdir -p "/usr/lib/pm-utils/sleep.d"
    WAKEUP_SCRIPT="/usr/lib/pm-utils/sleep.d/99ZZZ_KiraWakeup.sh"
    cat > $WAKEUP_SCRIPT <<< $WAKEUP_ENTRY
    chmod 555 $WAKEUP_SCRIPT
    
    touch $SETUP_CHECK
else
    echoInfo "INFO: Your system has all pre-requisites set"
fi
