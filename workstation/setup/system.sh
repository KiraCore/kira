
#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &> /dev/null

KIRA_SETUP_FILE="$KIRA_SETUP/system-v0.0.3" 
if [ ! -f "$KIRA_SETUP_FILE" ] ; then
    echo "INFO: Setting up system pre-requisites..."
    CDHelper text lineswap --insert="* hard nofile 999999" --prefix="* hard nofile" --path="/etc/security/limits.conf" --append-if-found-not=True --silent=$SILENT_MODE
    CDHelper text lineswap --insert="* soft nofile 999999" --prefix="* soft nofile" --path="/etc/security/limits.conf" --append-if-found-not=True --silent=$SILENT_MODE
    
    WAKEUP_ENTRY="#!/bin/sh
case \"\$1\" in
    resume)
        echo \"INFO: Restartin docker network manager...\"
        systemctl restart NetworkManager docker || echo \"ERROR: Failed to restart docker network manager\"
esac
exit 0"

    WAKEUP_SCRIPT="/usr/lib/pm-utils/sleep.d/99ZZZ_KiraWakeup.sh"
    cat > $WAKEUP_SCRIPT <<< $WAKEUP_ENTRY
    chmod 777 $WAKEUP_SCRIPT
    
    touch $KIRA_SETUP_FILE
else
    echo "INFO: Your system has all pre-requisites set"
fi
