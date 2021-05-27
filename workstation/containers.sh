#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/images.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart
cd $KIRA_HOME

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CONTAINERS BUILD SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "|    INFRA MODE: $INFRA_MODE"
echoWarn "| EXTERNAL SYNC: $EXTERNAL_SYNC"
echoWarn "------------------------------------------------"
set -x

mkdir -p $INTERX_REFERENCE_DIR
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "Genesis file was NOT found in the reference direcotry"
rm -fv "$INTERX_REFERENCE_DIR/genesis.json"

if [ "${NEW_NETWORK,,}" != "true" ] ; then 
    echoInfo "INFO: Attempting to access genesis file from local configuration..."
    [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Failed to locate genesis file, external sync is not possible" && exit 1
    ln -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
    chattr +i "$INTERX_REFERENCE_DIR/genesis.json"
    GENESIS_SHA256=$(sha256 "$LOCAL_GENESIS_PATH")
else
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
    rm -fv "$LOCAL_GENESIS_PATH"
    GENESIS_SHA256=""
fi

CDHelper text lineswap --insert="GENESIS_SHA256=\"$GENESIS_SHA256\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True

echoInfo "INFO: Starting containers build..."
globSet PRIV_CONN_PRIORITY "null"

globSet SEED_EXPOSED false
globSet SENTRY_EXPOSED false
globSet PRIV_SENTRY_EXPOSED false
globSet SNAPSHOT_EXPOSED true
globSet VALIDATOR_EXPOSED false
globSet FRONTEND_EXPOSED false
globSet INTERX_EXPOSED true

if [ "${INFRA_MODE,,}" == "local" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh && globSet VALIDATOR_EXPOSED true
    $KIRA_MANAGER/containers/start-sentry.sh && globSet SENTRY_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh
    $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
elif [ "${INFRA_MODE,,}" == "seed" ] ; then
    $KIRA_MANAGER/containers/start-seed.sh && globSet SEED_EXPOSED true
    $KIRA_MANAGER/containers/start-interx.sh
    [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-frontend.sh && globSet FRONTEND_EXPOSED true
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    if (! $(isFileEmpty $PUBLIC_SEEDS )) || (! $(isFileEmpty $PUBLIC_PEERS )) ; then
        # save snapshot from sentry first
        globSet PRIV_CONN_PRIORITY false
        $KIRA_MANAGER/containers/start-sentry.sh "true" && globSet SENTRY_EXPOSED true
        [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-priv-sentry.sh && globSet PRIV_SENTRY_EXPOSED true
    elif (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
        # save snapshot from private sentry first
        globSet PRIV_CONN_PRIORITY true
        $KIRA_MANAGER/containers/start-priv-sentry.sh "true" && globSet PRIV_SENTRY_EXPOSED true
        [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-sentry.sh && globSet SENTRY_EXPOSED true
    else
        echoWarn "WARNING: No public or priveate seeds were found, syning your node from external source will not be possible"
        exit 1
    fi

    $KIRA_MANAGER/containers/start-interx.sh
    [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    globSet VALIDATOR_EXPOSED true
    if [ "${EXTERNAL_SYNC,,}" == "true" ] ; then
        if (! $(isFileEmpty $PUBLIC_SEEDS )) || (! $(isFileEmpty $PUBLIC_PEERS )) ; then
            # save snapshot from sentry first
            globSet PRIV_CONN_PRIORITY false
            $KIRA_MANAGER/containers/start-sentry.sh "true"
            [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-priv-sentry.sh
        elif (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
            # save snapshot from private sentry first
            globSet PRIV_CONN_PRIORITY true
            $KIRA_MANAGER/containers/start-priv-sentry.sh "true"
            [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-sentry.sh
        else
            echoWarn "WARNING: No public or priveate seeds were found, syning your node from external source will not be possible"
            exit 1
        fi
    fi

    if [ "${DEPLOYMENT_MODE,,}" == "minimal" ] ; then
        ADDRBOOK_DST="$DOCKER_COMMON_RO/addrbook.json"
        (timeout 8 docker exec -i sentry cat "$SEKAID_HOME/config/addrbook.json" 2>&1 || echo "") > $ADDRBOOK_DST
        ($(isFileEmpty $ADDRBOOK_DST)) && (timeout 8 docker exec -i priv_sentry cat "$SEKAID_HOME/config/addrbook.json" 2>&1 || echo "") > $ADDRBOOK_DST
        $KIRA_SCRIPTS/container-delete.sh "sentry"
        $KIRA_SCRIPTS/container-delete.sh "priv_sentry"
        $KIRA_MANAGER/containers/start-validator.sh
        $KIRA_MANAGER/containers/start-interx.sh
    elif [ "${EXTERNAL_SYNC,,}" == "false" ] ; then
        globSet SENTRY_EXPOSED true
        globSet PRIV_SENTRY_EXPOSED true

        $KIRA_MANAGER/containers/start-validator.sh
        if [ "${DEPLOYMENT_MODE,,}" == "full" ] ; then
            $KIRA_MANAGER/containers/start-sentry.sh
            $KIRA_MANAGER/containers/start-priv-sentry.sh
        fi
        $KIRA_MANAGER/containers/start-interx.sh
    else
        globSet SENTRY_EXPOSED true
        globSet PRIV_SENTRY_EXPOSED true
        $KIRA_MANAGER/containers/start-interx.sh
        $KIRA_MANAGER/containers/start-validator.sh
    fi
else
    echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
    exit 1
fi

PORTS="$DEFAULT_SSH_PORT"
CONTAINERS_COUNT=0
if [ "$(globGet SEED_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SEED_P2P_PORT $KIRA_SEED_PROMETHEUS_PORT"
fi

if [ "$(globGet SENTRY_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_SENTRY_GRPC_PORT $KIRA_SENTRY_RPC_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_PROMETHEUS_PORT"
fi

if [ "$(globGet PRIV_SENTRY_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_PRIV_SENTRY_P2P_PORT $KIRA_PRIV_SENTRY_PROMETHEUS_PORT"
fi

if [ "$(globGet SNAPSHOT_EXPOSED)" == "true" ] ; then
    PORTS="$PORTS $KIRA_SNAPSHOT_P2P_PORT $KIRA_SNAPSHOT_PROMETHEUS_PORT"
fi

if [ "$(globGet VALIDATOR_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_VALIDATOR_P2P_PORT $KIRA_VALIDATOR_PROMETHEUS_PORT"
fi

if [ "$(globGet FRONTEND_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_FRONTEND_PORT"
fi

if [ "$(globGet INTERX_EXPOSED)" == "true" ] ; then
    CONTAINERS_COUNT=$((CONTAINERS_COUNT + 1))
    PORTS="$PORTS $KIRA_INTERX_PORT"
fi

CDHelper text lineswap --insert="CONTAINERS_COUNT=\"$CONTAINERS_COUNT\"" --prefix="CONTAINERS_COUNT=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="EXPOSED_PORTS=\"$PORTS\"" --prefix="PORTS=" --path=$ETC_PROFILE --append-if-found-not=True

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS BUILD SCRIPT            |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x