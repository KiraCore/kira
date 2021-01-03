
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"


KIRA_SETUP_FILE="$KIRA_SETUP/system-v0.0.5" 
if [ ! -f "$KIRA_SETUP_FILE" ] ; then
    echo "INFO: Update and Intall system tools and dependencies..."
    apt-get update -y --fix-missing
    apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
        pm-utils

    echo "INFO: Setting up system pre-requisites..."
    CDHelper text lineswap --insert="* hard nofile 999999" --prefix="* hard nofile" --path="/etc/security/limits.conf" --append-if-found-not=True --silent=$SILENT_MODE
    CDHelper text lineswap --insert="* soft nofile 999999" --prefix="* soft nofile" --path="/etc/security/limits.conf" --append-if-found-not=True --silent=$SILENT_MODE
    
    WAKEUP_ENTRY="#!/bin/sh
case \"\$1\" in
    resume)
        echo \"INFO: Reloading daemon...\"
        systemctl daemon-reload || echo \"ERROR: Failed daemon reload\"
        echo \"INFO: Restarting firewall...\"
        systemctl start firewalld || echo \"ERROR: Failed firewall restart\"
        firewall-cmd --complete-reload || echo \"ERROR: Failed firewall reload\"
        echo \"INFO: Restarting docker...\"
        systemctl restart docker || echo \"ERROR: Failed to restart docker\"
        echo \"INFO: Restarting docker network manager...\"
        systemctl restart NetworkManager docker || echo \"ERROR: Failed to restart docker network manager\"
esac
exit 0"

    mkdir -p "/usr/lib/pm-utils/sleep.d"
    WAKEUP_SCRIPT="/usr/lib/pm-utils/sleep.d/99ZZZ_KiraWakeup.sh"
    cat > $WAKEUP_SCRIPT <<< $WAKEUP_ENTRY
    chmod 555 $WAKEUP_SCRIPT
    
    touch $KIRA_SETUP_FILE
else
    echo "INFO: Your system has all pre-requisites set"
fi
