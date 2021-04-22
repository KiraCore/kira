#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

LATEST_BLOCK_HEIGHT=$1
PREVIOUS_HEIGHT=$2
HEIGHT=$3
CATCHING_UP=$4
CONSENSUS_STOPPED=$5

VALOPERS_FILE="$COMMON_READ/valopers"
CFG="$SEKAID_HOME/config/config.toml"

if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
    set +x
    echoWarn "WARNING: Blocks are not beeing produced or synced"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
     
    if [[ $LATEST_BLOCK_HEIGHT -ge 1 ]] && [[ $LATEST_BLOCK_HEIGHT -le $HEIGHT ]] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
        echoWarn "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
    else
        echoErr "ERROR: Block production stopped"
        sleep 10
        exit 1
    fi
else
    echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

exit 0