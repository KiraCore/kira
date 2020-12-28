
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

HASH_CHECK=$(echo "
$KIRA_REGISTRY_DNS-$KIRA_REGISTRY_IP
$KIRA_VALIDATOR_IP
ccc
" | md5sum | awk '{print $1}') 

SETUP_CHECK="$KIRA_SETUP/hosts-v0.0.7-$HASH_CHECK" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up default hosts..."
    CDHelper text lineswap --insert="$KIRA_REGISTRY_IP $KIRA_REGISTRY_DNS" --regex="$KIRA_REGISTRY_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True
    CDHelper text lineswap --insert="$KIRA_VALIDATOR_IP $KIRA_VALIDATOR_DNS" --regex="$KIRA_VALIDATOR_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True
    CDHelper text lineswap --insert="$KIRA_SENTRY_IP $KIRA_SENTRY_DNS" --regex="$KIRA_SENTRY_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True
    CDHelper text lineswap --insert="$KIRA_INTERX_IP $KIRA_INTERX_DNS" --regex="$KIRA_INTERX_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True
    CDHelper text lineswap --insert="$KIRA_FRONTEND_IP $KIRA_FRONTEND_DNS" --regex="$KIRA_FRONTEND_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True
    systemctl restart docker || echo "WARNING: Failed to restart docker"
    touch $SETUP_CHECK
else
    echo "INFO: Default host names were already defined"
fi
