
#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &> /dev/null

KIRA_SETUP_HOSTS="$KIRA_SETUP/hosts-v0.0.4-$KIRA_REGISTRY_NAME" 
if [ ! -f "$KIRA_SETUP_HOSTS" ] ; then
    echo "INFO: Setting up default hosts..."
    CDHelper text lineswap --insert="$KIRA_REGISTRY_IP $KIRA_REGISTRY_NAME" --prefix="$KIRA_REGISTRY_IP" --path=$HOSTS_PATH --prepend-if-found-not=True --silent=$SILENT_MODE
    
    systemctl restart docker || echo "WARNING: Failed to restart docker"
    touch $KIRA_SETUP_HOSTS
else
    echo "INFO: Default host names were already defined"
fi
