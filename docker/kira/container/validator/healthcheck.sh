#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

LATEST_BLOCK_HEIGHT=$1
CONSENSUS_STOPPED=$2

VALOPERS_FILE="$COMMON_READ/valopers"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
CFG="$SEKAID_HOME/config/config.toml"

touch $BLOCK_HEIGHT_FILE

SEKAID_STATUS=$(sekaid status 2>&1 || echo -n "")
CATCHING_UP=$(echo $SEKAID_STATUS | jsonQuickParse "catching_up" || echo -n "")
HEIGHT=$(echo $SEKAID_STATUS | jsonQuickParse "latest_block_height" || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0

if [ "${CATCHING_UP,,}" == "true" ]; then
    echoInfo "INFO: Success, node is catching up! ($HEIGHT)"
    exit 0
fi

PREVIOUS_HEIGHT=$(tryCat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

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



echoInfo "INFO: Latest Block Height: $HEIGHT"

# block time should vary from minimum of 5.1s to 100ms depending on the validator count. The more validators, the shorter the block time
echoInfo "INFO: Updating commit timeout..."
ACTIVE_VALIDATORS=$(jsonQuickParse "active_validators" $VALOPERS_FILE || echo "0")
(! $(isNaturalNumber "$ACTIVE_VALIDATORS")) && ACTIVE_VALIDATORS=0
if [ "${ACTIVE_VALIDATORS}" != "0" ] ; then
    TIMEOUT_COMMIT=$(echo "scale=3; ((( 5 / ( $ACTIVE_VALIDATORS + 1 ) ) * 1000 ) + 1000) " | bc)
    TIMEOUT_COMMIT=$(echo "scale=0; ( $TIMEOUT_COMMIT / 1 ) " | bc)
    (! $(isNaturalNumber "$TIMEOUT_COMMIT")) && TIMEOUT_COMMIT="5000"
    TIMEOUT_COMMIT="${TIMEOUT_COMMIT}ms"
    
    if [ "${TIMEOUT_COMMIT}" != "$CFG_timeout_commit" ] ; then
        echoInfo "INFO: Commit timeout will be changed to $TIMEOUT_COMMIT"
        CDHelper text lineswap --insert="CFG_timeout_commit=${TIMEOUT_COMMIT}" --prefix="CFG_timeout_commit=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="timeout_commit = \"${TIMEOUT_COMMIT}\"" --prefix="timeout_commit =" --path=$CFG
    fi
fi

exit 0