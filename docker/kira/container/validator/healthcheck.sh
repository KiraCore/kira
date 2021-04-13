#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

START_TIME="$(date -u +%s)"
echoInfo "INFO: Starting healthcheck $START_TIME"

VALOPERS_FILE="$COMMON_READ/valopers"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
CFG="$SEKAID_HOME/config/config.toml"

touch $BLOCK_HEIGHT_FILE

HEIGHT=$(sekaid status 2>&1 | jsonQuickParse "latest_block_height" || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
    echoWarn "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
    sleep 10
    exit 1
else
    echoInfo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echoInfo "INFO: Latest Block Height: $HEIGHT"

# block time should vary from minimum of 5.1s to 100ms depending on the validator count. The more vlaidators, the shorter the block time
echoInfo "INFO: Updating commit timeout..."
ACTIVE_VALIDATORS=$(jq -rc '.status.active_validators' $VALOPERS_FILE || echo "0")
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

echo "------------------------------------------------"
echo "| FINISHED: HEALTHCHECK                        |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echo "------------------------------------------------"
exit 0