#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart
cd $KIRA_HOME

NEW_NETWORK=$(globGet NEW_NETWORK)
EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC $GLOBAL_COMMON_RO)
UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)

if [ $INIT_MODE == "upgrade" ] ; then
    [ "$(globGet UPGRADE_INSTATE)" == "true" ] && UPGRADE_MODE="soft" || UPGRADE_MODE="hard"
else
    UPGRADE_MODE="none"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CONTAINERS BUILD SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "|      INFRA MODE: $INFRA_MODE"
echoWarn "|       INIT MODE: $INIT_MODE"
echoWarn "|    UPGRADE MODE: $UPGRADE_MODE"
echoWarn "|   EXTERNAL SYNC: $EXTERNAL_SYNC"
echoWarn "| UPGRADE INSTATE: $UPGRADE_INSTATE"
echoWarn "------------------------------------------------"
set -x

mkdir -p $INTERX_REFERENCE_DIR
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "Genesis file was NOT found in the reference direcotry"
rm -fv "$INTERX_REFERENCE_DIR/genesis.json"

if [ "$(globGet NEW_NETWORK)" == "false" ] && ( [ "$UPGRADE_MODE" == "none" ] || [ "$UPGRADE_MODE" == "soft" ] ) ; then 
    echoInfo "INFO: Attempting to access genesis file from local configuration..."
    [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Failed to locate genesis file, external sync is not possible" && exit 1
    ln -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
    chattr +i "$INTERX_REFERENCE_DIR/genesis.json"
    chattr +i "$LOCAL_GENESIS_PATH"
    GENESIS_SHA256=$(sha256 "$LOCAL_GENESIS_PATH")
else
    echoInfo "INFO: Waiping local genesis, new network will be launched or upgrade executed!"
    rm -fv "$LOCAL_GENESIS_PATH"
    GENESIS_SHA256=""
fi

globSet GENESIS_SHA256 "$GENESIS_SHA256"

echoInfo "INFO: Starting containers build..."
systemctl restart docker || ( echoErr "ERROR: Failed to start docker" && exit 1 )
echoInfo "INFO: Recreating docker networks..."
sleep 3

globSet SEED_EXPOSED false
globSet SENTRY_EXPOSED false
globSet VALIDATOR_EXPOSED false
globSet INTERX_EXPOSED true

# setting infra containers count to infinite, to notify in the manager that not all containers launched during setup
globSet INFRA_CONTAINERS_COUNT "100"

set -x
set -e

globSet seed_STARTED false
globSet sentry_STARTED false
globSet validator_STARTED false
globSet interx_STARTED false

if [ "${INFRA_MODE,,}" == "seed" ] ; then
    globSet SEED_EXPOSED true
    $KIRA_MANAGER/containers/start-seed.sh
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    globSet SENTRY_EXPOSED true
    $KIRA_MANAGER/containers/start-sentry.sh
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    globSet VALIDATOR_EXPOSED true
    $KIRA_MANAGER/containers/start-validator.sh
else
    echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
    globSet CONTAINERS_BUILD_SUCCESS "false"
    exit 1
fi

globSet UPGRADE_DONE "true"
globSet UPGRADE_TIME "$(date2unix $(date))"

if [ "$(globGet seed_STARTED)" == "true" ] || [ "$(globGet sentry_STARTED)" == "true" ] || [ "$(globGet validator_STARTED)" == "true" ] ; then
    $KIRA_MANAGER/containers/start-interx.sh
fi

PORTS="$DEFAULT_SSH_PORT"
CONTAINERS_COUNT=0
if [ "$(globGet SEED_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SEED_P2P_PORT $KIRA_SEED_RPC_PORT $KIRA_SEED_GRPC_PORT $KIRA_SEED_PROMETHEUS_PORT"
fi

if [ "$(globGet SENTRY_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SENTRY_RPC_PORT $KIRA_SENTRY_GRPC_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_PROMETHEUS_PORT"
fi

if [ "$(globGet VALIDATOR_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_VALIDATOR_P2P_PORT $KIRA_VALIDATOR_RPC_PORT $KIRA_VALIDATOR_GRPC_PORT $KIRA_VALIDATOR_PROMETHEUS_PORT"
fi

if [ "$(globGet INTERX_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_INTERX_PORT"
fi

globSet INFRA_CONTAINERS_COUNT "$CONTAINERS_COUNT"
globSet EXPOSED_PORTS "$PORTS"

seed_STARTED=$(globGet seed_STARTED)
sentry_STARTED=$(globGet sentry_STARTED)
validator_STARTED=$(globGet validator_STARTED)
interx_STARTED=$(globGet interx_STARTED)

if [ "${interx_STARTED,,}" != "true" ] ; then
    globSet CONTAINERS_BUILD_SUCCESS "false"
    set +x
    echoErr "ERROR: Failed to deploy one of the essential containers!"
    echoErr "ERROR:      Seed started: '$seed_STARTED'"
    echoErr "ERROR:    Sentry started: '$sentry_STARTED'"
    echoErr "ERROR: Validator started: '$validator_STARTED'"
    echoErr "ERROR:    INTERX started: '$interx_STARTED'"
    exit 1
else
    echoInfo "INFO: Containers deployment suceeded..."
    globSet CONTAINERS_BUILD_SUCCESS "true"
    echoInfo "INFO: Creating snapshot..."
    [ "${INFRA_MODE,,}" == "latest" ] && SNAPSHOT_TARGET="validator" || SNAPSHOT_TARGET="${INFRA_MODE,,}"
    globSet IS_SCAN_DONE "false"
    globSet "${SNAPSHOT_TARGET}_SYNCING" "true"
    globSet SNAPSHOT_TARGET "$SNAPSHOT_TARGET"
    [ -z "$(globGet SNAPSHOT_EXECUTE)" ] && globSet SNAPSHOT_EXECUTE "true"
    [ -z "$(globGet SNAPSHOT_UNHALT)" ] && globSet SNAPSHOT_UNHALT "true"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS BUILD SCRIPT            |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x