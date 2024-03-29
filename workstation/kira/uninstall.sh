#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/uninstall.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# $KIRA_MANAGER/kira/uninstall.sh
# kira --uninstall=true
set -x

# DANGER! this script wipes all data from the node including cryptographic secrets!

systemctl stop kiraup    || echoWarn "WARNING: Service 'kiraup' failed to be stopped"   
systemctl stop kiraplan  || echoWarn "WARNING: Service 'kiraplan' failed to be stopped" 
systemctl stop kirascan  || echoWarn "WARNING: Service 'kirascan' failed to be stopped" 
systemctl stop kiraclean || echoWarn "WARNING: Service 'kiraclean' failed to be stopped"
systemctl stop docker    || echoWarn "WARNING: Service 'docker' failed to be stopped"   

chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the interx reference direcotry"
rm -fv "$LOCAL_GENESIS_PATH" "$INTERX_REFERENCE_DIR/genesis.json"

rm -rfv "$KIRA_SNAP_PATH" "$KIRA_DUMP" "$KIRA_SECRETS" \
 "$KIRA_LOGS" "$KIRA_SNAP" "$KIRA_SCAN" "$KIRA_CONFIGS" \
 "$KIRA_INFRA" "$KIRA_BIN" "$KIRA_SETUP" "$KIRA_MANAGER" \
 "$KIRA_COMMON" "$KIRA_WORKSTATION" "$DOCKER_HOME" "$DOCKER_COMMON" \
 "$DOCKER_COMMON_RO" "$GLOBAL_COMMON_RO" "$KIRA_DOCKER" "$KIRAMGR_SCRIPTS"

exec -a "console" /bin/bash

