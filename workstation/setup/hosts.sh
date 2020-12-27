
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

SETUP_CHECK="$KIRA_SETUP/hosts-v0.0.6-$KIRA_REGISTRY_NAME-$KIRA_REGISTRY_PORT-$KIRA_REGISTRY_IP" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up default hosts..."
    CDHelper text lineswap --insert="$KIRA_REGISTRY_IP $KIRA_REGISTRY_NAME" --regex="$KIRA_REGISTRY_NAME" --path=$HOSTS_PATH --prepend-if-found-not=True
    systemctl restart docker || echo "WARNING: Failed to restart docker"
    touch $SETUP_CHECK
else
    echo "INFO: Default host names were already defined"
fi
