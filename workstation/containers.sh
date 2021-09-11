#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart
cd $KIRA_HOME

EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC $GLOBAL_COMMON_RO)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CONTAINERS BUILD SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "|    INFRA MODE: $INFRA_MODE"
echoWarn "| EXTERNAL SYNC: $EXTERNAL_SYNC"
echoWarn "------------------------------------------------"
set -x

mkdir -p $INTERX_REFERENCE_DIR
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "Genesis file was NOT found in the reference direcotry"
rm -fv "$INTERX_REFERENCE_DIR/genesis.json"

if [ "${NEW_NETWORK,,}" != "true" ] ; then 
    echoInfo "INFO: Attempting to access genesis file from local configuration..."
    [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Failed to locate genesis file, external sync is not possible" && exit 1
    ln -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
    chattr +i "$INTERX_REFERENCE_DIR/genesis.json"
    GENESIS_SHA256=$(sha256 "$LOCAL_GENESIS_PATH")
else
    rm -fv "$LOCAL_GENESIS_PATH"
    GENESIS_SHA256=""
fi

globSet GENESIS_SHA256 "$GENESIS_SHA256"

echoInfo "INFO: Starting containers build..."

globSet SEED_EXPOSED false
globSet SENTRY_EXPOSED false
globSet VALIDATOR_EXPOSED false
globSet FRONTEND_EXPOSED false
globSet INTERX_EXPOSED false

# setting infra containers count to infinite, to notify in the manager that not all containers launched during setup
globSet INFRA_CONTAINERS_COUNT "100"

if ($(isFileEmpty $PUBLIC_SEEDS)) && ($(isFileEmpty $PUBLIC_PEERS )) ; then
    cat $PRIVATE_SEEDS > $PUBLIC_SEEDS
    cat $PRIVATE_PEERS > $PUBLIC_PEERS
fi

if [ "${NEW_NETWORK,,}" != "true" ] && ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) ; then 
    echoErr "ERROR: Containers setup can't proceed, no PUBLIC SEERDS or PEERS were define on existing network"
    exit 1
fi

if [ "${INFRA_MODE,,}" == "local" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh && globSet VALIDATOR_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh && globSet INTERX_EXPOSED true
    $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
elif [ "${INFRA_MODE,,}" == "seed" ] ; then
    $KIRA_MANAGER/containers/start-seed.sh && globSet SEED_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh && globSet INTERX_EXPOSED true
    $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    $KIRA_MANAGER/containers/start-sentry.sh && globSet SENTRY_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh && globSet INTERX_EXPOSED true
    $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh && globSet VALIDATOR_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh && globSet INTERX_EXPOSED true
    $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
else
    echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
    exit 1
fi

PORTS="$DEFAULT_SSH_PORT"
CONTAINERS_COUNT=0
if [ "$(globGet SEED_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SEED_P2P_PORT $KIRA_SEED_RPC_PORT $KIRA_SEED_PROMETHEUS_PORT"
fi

if [ "$(globGet SENTRY_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SENTRY_RPC_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_PROMETHEUS_PORT"
fi

if [ "$(globGet VALIDATOR_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_VALIDATOR_P2P_PORT $KIRA_VALIDATOR_RPC_PORT $KIRA_VALIDATOR_PROMETHEUS_PORT"
fi

if [ "$(globGet FRONTEND_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_FRONTEND_PORT"
fi

if [ "$(globGet INTERX_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_INTERX_PORT"
fi

globSet INFRA_CONTAINERS_COUNT "$CONTAINERS_COUNT"
globSet EXPOSED_PORTS "$EXPOSED_PORTS"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS BUILD SCRIPT            |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x