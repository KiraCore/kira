#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

LATEST_BLOCK_HEIGHT=$1
PREVIOUS_HEIGHT=$2
HEIGHT=$3
CATCHING_UP=$4
CONSENSUS_STOPPED=$5

timerStart "healthcheck"
VALOPERS_FILE="$COMMON_READ/valopers"
CFG="$SEKAID_HOME/config/config.toml"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: ${NODE_TYPE^^} HEALTHCHECK"
echoWarn "|-----------------------------------------------"
echoWarn "| LATEST BLOCK HEIGHT: $LATEST_BLOCK_HEIGHT"
echoWarn "|     PREVIOUS HEIGHT: $PREVIOUS_HEIGHT"
echoWarn "|              HEIGHT: $HEIGHT"
echoWarn "|         CATCHING UP: $CATCHING_UP"
echoWarn "|   CONSENSUS STOPPED: $CONSENSUS_STOPPED"
echoWarn "------------------------------------------------"
set -x

if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
    set +x
    echoWarn "WARNING: Blocks are not beeing produced or synced by $NODE_TYPE"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
     
    echoErr "ERROR: Block production or sync stopped more than $(timerSpan catching_up) seconds ago"
    sleep 10
    exit 1
else
    echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: ${NODE_TYPE^^} HEALTHCHECK"
echoInfo "|  ELAPSED: $(timerSpan healthcheck) seconds"
echoInfo "------------------------------------------------"
set -x
exit 0