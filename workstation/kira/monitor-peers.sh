#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-peers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat $KIRA_SCAN/peers.logs
set -x

timerStart
PEERS_SCAN_PATH="$KIRA_SCAN/peers"
SNAPS_SCAN_PATH="$KIRA_SCAN/snaps"
INTERX_PEERS_PATH="$INTERX_REFERENCE_DIR/peers.txt"
INTERX_SNAPS_PATH="$INTERX_REFERENCE_DIR/snaps.txt"
MIN_SNAP_SIZE="524288"


while [ "$(globGet IS_SCAN_DONE)" != "true" ] ; do
    echo "INFO: Waiting for monitor scan to finalize run..."
    sleep 10
done

SEKAI_ADDRBOOK_FILE="$DOCKER_HOME/$(globGet INFRA_MODE)/config/addrbook.json"
INTERX_ADDRBOOK_FILE=$(globFile KIRA_ADDRBOOK "$DOCKER_COMMON/interx/kiraglob")
CONTAINERS=$(globGet CONTAINERS)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA PEERS SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|  SEKAI_ADDRBOOK_FILE: $SEKAI_ADDRBOOK_FILE"
echoWarn "| INTERX_ADDRBOOK_FILE: $INTERX_ADDRBOOK_FILE"
echoWarn "|           CONTAINERS: $CONTAINERS"
echoWarn "------------------------------------------------"
set -x

SAME_FILES=$(cmp --silent $SEKAI_ADDRBOOK_FILE $INTERX_ADDRBOOK_FILE && echo "true" || echo "false")

if [ -f $SEKAI_ADDRBOOK_FILE ] && [ "$SAME_FILES" != "true" ] ; then
    echoInfo "INFO: Saving address book..."
    cp -afv $SEKAI_ADDRBOOK_FILE $INTERX_ADDRBOOK_FILE || echoErr "ERROR: Failed to provision interx with addrbook copy!"
else
    echoInfo "INFO: Address book file was already provisioned"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: PEERS MONITOR                      |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 60