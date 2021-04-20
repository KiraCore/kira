#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f | ccze -A
set -x


sleep 60
exit 0

UPDATE_LOGS_DIR="$KIRA_UPDATE/logs"


set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA UPDATE & SETUP SERVICE         |"
echoWarn "|-----------------------------------------------"
echoWarn "| UPDATE LOGS DIR: $UPDATE_LOGS_DIR"
echoWarn "------------------------------------------------"
set -x


UPDATE_CHECK="$KIRA_UPDATE/tools-install-v0.0.1"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Installing essential tools and dependecies"


    touch $UPDATE_CHECK
else
    echoInfo "INFO: Essential tools and dependecies were already installed"
fi


# $KIRA_MANAGER/setup.sh

sleep 60