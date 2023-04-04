#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart
cd "$(globGet KIRA_HOME)"

NEW_NETWORK=$(globGet NEW_NETWORK)
EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC $GLOBAL_COMMON_RO)
UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)

if [ "$INIT_MODE" == "upgrade" ] ; then
    [ "$UPGRADE_INSTATE" == "true" ] && UPGRADE_MODE="soft" || UPGRADE_MODE="hard"
else
    UPGRADE_MODE="none"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CONTAINERS BUILD SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "|      INFRA MODE: $(globGet INFRA_MODE)"
echoWarn "|       INIT MODE: $INIT_MODE"
echoWarn "|    UPGRADE MODE: $UPGRADE_MODE"
echoWarn "|   EXTERNAL SYNC: $EXTERNAL_SYNC"
echoWarn "| UPGRADE INSTATE: $UPGRADE_INSTATE"
echoWarn "|   KIRA HOME DIR: $(globGet KIRA_HOME)"
echoWarn "------------------------------------------------"
set -x

mkdir -p $INTERX_REFERENCE_DIR
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "Genesis file was NOT found in the reference direcotry"
rm -fv "$INTERX_REFERENCE_DIR/genesis.json"

if [ "$NEW_NETWORK" == "false" ] && ( [ "$UPGRADE_MODE" == "none" ] || [ "$UPGRADE_MODE" == "soft" ] ) ; then 
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
$KIRA_COMMON/docker-restart.sh
echoInfo "INFO: Recreating docker networks..."
sleep 3

globSet SEED_EXPOSED false
globSet SENTRY_EXPOSED false
globSet VALIDATOR_EXPOSED false
globSet INTERX_EXPOSED true

# setting default infra containers count to 2, to notify in the manager that not all containers launched during setup
globSet INFRA_CONTAINERS_COUNT "2"

set -x
set -e

globSet seed_STARTED false
globSet sentry_STARTED false
globSet validator_STARTED false
globSet interx_STARTED false

if [ "$(globGet INFRA_MODE)" == "seed" ] ; then
    globSet SEED_EXPOSED true
    $KIRA_MANAGER/containers/start-seed.sh
elif [ "$(globGet INFRA_MODE)" == "sentry" ] ; then
    globSet SENTRY_EXPOSED true
    $KIRA_MANAGER/containers/start-sentry.sh
elif [ "$(globGet INFRA_MODE)" == "validator" ] ; then
    globSet VALIDATOR_EXPOSED true
    $KIRA_MANAGER/containers/start-validator.sh
else
    echoErr "ERROR: Unrecognized infra mode $(globGet INFRA_MODE)"
    globSet CONTAINERS_BUILD_SUCCESS "false"
    exit 1
fi

globSet UPGRADE_DONE "true"
globSet UPGRADE_TIME "$(date2unix $(date))"

if [ "$(globGet seed_STARTED)" == "true" ] || [ "$(globGet sentry_STARTED)" == "true" ] || [ "$(globGet validator_STARTED)" == "true" ] ; then
    $KIRA_MANAGER/containers/start-interx.sh
fi

PORTS="$(globGet DEFAULT_SSH_PORT) $(globGet CUSTOM_PROMETHEUS_PORT) $(globGet CUSTOM_GRPC_PORT) $(globGet CUSTOM_RPC_PORT) $(globGet CUSTOM_P2P_PORT)"
CONTAINERS_COUNT=0
[ "$(globGet SEED_EXPOSED)" == "true" ] && CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
[ "$(globGet SENTRY_EXPOSED)" == "true" ] && CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
[ "$(globGet VALIDATOR_EXPOSED)" == "true" ] && CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))

if [ "$(globGet INTERX_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $(globGet CUSTOM_INTERX_PORT)"
fi

globSet INFRA_CONTAINERS_COUNT "$CONTAINERS_COUNT"
globSet EXPOSED_PORTS "$PORTS"

declare -l seed_STARTED=$(globGet seed_STARTED)
declare -l sentry_STARTED=$(globGet sentry_STARTED)
declare -l validator_STARTED=$(globGet validator_STARTED)
declare -l interx_STARTED=$(globGet interx_STARTED)

if [ "$interx_STARTED" != "true" ] ; then
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
    SNAPSHOT_TARGET="$(globGet INFRA_MODE)"
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