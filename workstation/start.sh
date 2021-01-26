#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

SKIP_UPDATE=$1
START_TIME_LAUNCH="$(date -u +%s)"
PUBLIC_SEEDS="$KIRA_CONFIGS/public_seeds"
PRIVATE_SEEDS="$KIRA_CONFIGS/private_seeds"

cd $HOME

set +x
echo "------------------------------------------------"
echo "| STARTED: LAUNCH SCRIPT                       |"
echo "|-----------------------------------------------"
echo "|  SKIP UPDATE: $SKIP_UPDATE"
echo "| SEKAI BRANCH: $SEKAI_BRANCH"
echo "------------------------------------------------"
set -x

[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echo "INFO: Updating kira repository and fetching changes..."
if [ "$SKIP_UPDATE" == "False" ]; then
    $KIRA_MANAGER/setup.sh "$SKIP_UPDATE"
    $KIRA_MANAGER/networking.sh
    source $KIRA_MANAGER/start.sh "True"
    exit 0
fi

set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echo "INFO: Restarting registry..."
$KIRA_SCRIPTS/container-restart.sh "registry" &

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    $KIRA_SCRIPTS/container-delete.sh "$name"
done

wait

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build images

set -e

$KIRAMGR_SCRIPTS/update-base-image.sh
$KIRAMGR_SCRIPTS/update-kira-image.sh & 
$KIRAMGR_SCRIPTS/update-interx-image.sh &
$KIRAMGR_SCRIPTS/update-frontend-image.sh &

wait

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate node_key.json for validator & sentry.

rm -rfv "$DOCKER_COMMON" && mkdir -p "$DOCKER_COMMON"
cp -rfv "$KIRA_DOCKER/configs/." "$DOCKER_COMMON"

# Load or generate secret mnemonics
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

$KIRAMGR_SCRIPTS/restart-networks.sh "false" # restarts all network without re-connecting containers

# Start Containers

if [ "${INFRA_MODE,,}" == "local" ]; then
    CDHelper text lineswap --insert="EXTERNAL_SYNC=false" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True
    $KIRA_MANAGER/containers/start-validator.sh 
    $KIRA_MANAGER/containers/start-sentry.sh 
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "sentry" ]; then
    CDHelper text lineswap --insert="EXTERNAL_SYNC=true" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True
    $KIRA_MANAGER/containers/start-sentry.sh
    $KIRA_MANAGER/containers/start-priv-sentry.sh 
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "validator" ]; 

    if [[ -z $(grep '[^[:space:]]' $PUBLIC_SEEDS) ]] ; then
        CDHelper text lineswap --insert="EXTERNAL_SYNC=false" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True
        echoInfo "INFO: Launching local network..."
        $KIRA_MANAGER/containers/start-validator.sh 
        $KIRA_MANAGER/containers/start-sentry.sh 
        $KIRA_MANAGER/containers/start-priv-sentry.sh 
        $KIRA_MANAGER/containers/start-interx.sh 
        $KIRA_MANAGER/containers/start-frontend.sh
    else
        CDHelper text lineswap --insert="EXTERNAL_SYNC=true" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True
        echoInfo "INFO: Nodes will be synced from the external seed node"
        $KIRA_MANAGER/containers/start-sentry.sh

        if [[ -z $(grep '[^[:space:]]' $PRIVATE_SEEDS) ]] ; then
            echoInfo "INFO: No private seeds were configured, using internal public seed node"
            SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$KIRA_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
            echo "$SENTRY_SEED" > $PRIVATE_SEEDS
            $KIRA_MANAGER/containers/start-priv-sentry.sh 
        fi

        $KIRA_MANAGER/containers/start-interx.sh 
        $KIRA_MANAGER/containers/start-frontend.sh
        $KIRA_MANAGER/containers/start-validator.sh 
    fi
    
else
  echo "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi


set +x
echo "------------------------------------------------"
echo "| FINISHED: LAUNCH SCRIPT                      |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
echo "------------------------------------------------"
set -x