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
    CDHelper text lineswap --insert="GENESIS_SHA256=\"$GENESIS_SHA256\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
else
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
    rm -fv "$LOCAL_GENESIS_PATH"
fi

echoInfo "INFO: Starting containers build..."
globSet PRIV_CONN_PRIORITY "null"

if [ "${INFRA_MODE,,}" == "local" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh 
    $KIRA_MANAGER/containers/start-sentry.sh 
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh
elif [ "${INFRA_MODE,,}" == "seed" ] ; then
    $KIRA_MANAGER/containers/start-seed.sh
    $KIRA_MANAGER/containers/start-interx.sh
    [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-frontend.sh
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    if (! $(isFileEmpty $PUBLIC_SEEDS )) || (! $(isFileEmpty $PUBLIC_PEERS )) ; then
        # save snapshot from sentry first
        globSet PRIV_CONN_PRIORITY false
        $KIRA_MANAGER/containers/start-sentry.sh "true"
        $KIRA_MANAGER/containers/start-priv-sentry.sh
    elif (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
        # save snapshot from private sentry first
        globSet PRIV_CONN_PRIORITY true
        $KIRA_MANAGER/containers/start-priv-sentry.sh "true"
        $KIRA_MANAGER/containers/start-sentry.sh
    else
        echoWarn "WARNING: No public or priveate seeds were found, syning your node from external source will not be possible"
        exit 1
    fi

    $KIRA_MANAGER/containers/start-seed.sh
    $KIRA_MANAGER/containers/start-interx.sh 
    [ "${DEPLOYMENT_MODE,,}" == "full" ] && $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
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
        $KIRA_MANAGER/containers/start-validator.sh
        if [ "${DEPLOYMENT_MODE,,}" == "full" ] ; then
            $KIRA_MANAGER/containers/start-sentry.sh 
            $KIRA_MANAGER/containers/start-priv-sentry.sh
        fi
        $KIRA_MANAGER/containers/start-interx.sh
    else 
        $KIRA_MANAGER/containers/start-interx.sh
        $KIRA_MANAGER/containers/start-validator.sh 
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

echoInfo "INFO: Containers build was finalized.."
docker image prune -a -f || echoErr "ERROR: Failed to prune dangling images!"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS BUILD SCRIPT            |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x