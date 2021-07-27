#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart
TMP_GENESIS_PATH="/tmp/genesis.json"
cd $KIRA_HOME

# find top largest files: find / -xdev -type f -size +100M -exec ls -la {} \; | sort -nk 5

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CLEANUP SCRIPT                       |"
echoWarn "|-----------------------------------------------"
echoWarn "|         SCAN DIR: $KIRA_SCAN"
echoWarn "|    DOCKER COMMON: $DOCKER_COMMON"
echoWarn "| DOCKER COMMON RO: $DOCKER_COMMON_RO"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Restarting docker..."
systemctl daemon-reload  || echoErr "ERROR: Failed to reload systemctl daemon"
systemctl restart docker || ( echoErr "ERROR: Failed to restart docker service" && exit 1 )

sleep 3

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    $KIRA_SCRIPTS/container-delete.sh "$name"
done

echoInfo "INFO: KIRA Scan service cleanup..."
rm -frv "$KIRA_SCAN" && mkdir -p "$KIRA_SCAN"

echoInfo "INFO: Pruning dangling images..."
docker image prune -a -f || echoErr "ERROR: Failed to prune dangling images!"

systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )

echoInfo "INFO: Docker common directories cleanup..."
rm -fv $TMP_GENESIS_PATH
[ "${NEW_NETWORK,,}" == "false" ] && cp -afv $LOCAL_GENESIS_PATH $TMP_GENESIS_PATH
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
rm -rfv "$DOCKER_COMMON" "$DOCKER_COMMON_RO"
rm -fv $LOCAL_GENESIS_PATH
mkdir -p "$DOCKER_COMMON" "$DOCKER_COMMON_RO" "$GLOBAL_COMMON_RO" 
[ "${NEW_NETWORK,,}" == "false" ] && cp -afv $TMP_GENESIS_PATH $LOCAL_GENESIS_PATH

echoInfo "INFO: Restarting firewall settings..."
$KIRA_MANAGER/networking.sh

echoInfo "INFO: Loading secrets & generating mnemonics..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

echoInfo "INFO: Recreating docker networks..."
declare -a networks=("kiranet" "sentrynet" "servicenet")
declare -a subnets=("$KIRA_VALIDATOR_SUBNET" "$KIRA_SENTRY_SUBNET" "$KIRA_SERVICE_SUBNET")
len=${#networks[@]}

MTU=$(globGet MTU)

for (( i=0; i<${len}; i++ )) ; do
    network=${networks[$i]}
    subnet=${subnets[$i]}
    echoInfo "INFO: Recreating $network network and $subnet subnet..."
    docker network rm $network || echoWarn "WARNING: Failed to remove $network network"
    docker network create --opt com.docker.network.driver.mtu=$MTU --subnet=$subnet $network || echoWarn "WARNING: Failed to create $network network"
done

# $KIRAMGR_SCRIPTS/restart-networks.sh "false" # restarts all network without re-connecting containers
$KIRA_MANAGER/scripts/update-ifaces.sh

echoInfo "INFO: Updating IP addresses info..."
systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )
i=0 && LOCAL_IP="" && PUBLIC_IP=""
while ( (! $(isIp "$LOCAL_IP")) && (! $(isPublicIp "$PUBLIC_IP")) ) ; do
    i=$((i + 1))
    PUBLIC_IP=$(globGet "PUBLIC_IP")
    LOCAL_IP=$(globGet "LOCAL_IP")
    [ "$i" == "30" ] && echoErr "ERROR: Public IPv4 ($PUBLIC_IP) or Local IPv4 ($LOCAL_IP) address could not be found. Setup CAN NOT continue!" && exit 1 
    echoInfo "INFO: Waiting for public and local IPv4 address to be updated..."
    sleep 30
done

echoInfo "INFO: Setting up snapshots and geesis file..."
DOCKER_SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.zip"
rm -fv $DOCKER_SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    ln -fv "$KIRA_SNAP_PATH" "$DOCKER_SNAP_DESTINATION"
else
    echoWarn "WARNING: Snapshot file '$KIRA_SNAP_PATH' was NOT found, slow sync will be performed!"
fi

echoInfo "INFO: Setting up essential environment variables..."
if [ "${INFRA_MODE,,}" == "local" ] ; then
    EXTERNAL_SYNC="false"
elif [ "${INFRA_MODE,,}" == "seed" ] ; then
    EXTERNAL_SYNC="true"
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    EXTERNAL_SYNC="true"
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    if [ "${NEW_NETWORK,,}" == "true" ] || ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) && ($(isFileEmpty $PRIVATE_SEEDS )) && ($(isFileEmpty $PRIVATE_PEERS )) ) ; then
        EXTERNAL_SYNC="false" 
    else
        EXTERNAL_SYNC="true"
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

[ "${EXTERNAL_SYNC,,}" == "false" ] && echoInfo "INFO: Nodes will be synced from the pre-generated genesis in the '$INFRA_MODE' mode"
[ "${EXTERNAL_SYNC,,}" == "true" ] && echoInfo "INFO: Nodes will be synced from the external seed node in the '$INFRA_MODE' mode"

MIN_HEIGHT=$(globGet MIN_HEIGHT)

globSet EXTERNAL_SYNC "$EXTERNAL_SYNC"
globSet INFRA_MODE "$INFRA_MODE"
globSet KIRA_SETUP_VER "$KIRA_SETUP_VER"
globSet NEW_NETWORK "$NEW_NETWORK"
globSet DEPLOYMENT_MODE "$DEPLOYMENT_MODE"
globSet MIN_HEIGHT $HEIGHT

globSet EXTERNAL_SYNC "$EXTERNAL_SYNC" $GLOBAL_COMMON_RO
globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO
globSet KIRA_SETUP_VER "$KIRA_SETUP_VER" $GLOBAL_COMMON_RO
globSet NEW_NETWORK "$NEW_NETWORK" $GLOBAL_COMMON_RO
globSet DEPLOYMENT_MODE "$DEPLOYMENT_MODE" $GLOBAL_COMMON_RO
globSet MIN_HEIGHT $HEIGHT $GLOBAL_COMMON_RO

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CLEANUP SCRIPT                      |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x