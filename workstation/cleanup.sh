#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart

NEW_NETWORK=$(globGet NEW_NETWORK)
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
for name in $CONTAINERS; do
    $KIRA_COMMON/container-delete.sh "$name"
    globDel "${name}_SEKAID_STATUS"
done

echoInfo "INFO: KIRA Scan service cleanup..."
rm -frv "$KIRA_SCAN" && mkdir -p "$KIRA_SCAN"

echoInfo "INFO: Pruning dangling images..."
docker image prune -a -f || echoErr "ERROR: Failed to prune dangling images!"

systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )

echoInfo "INFO: Docker common directories cleanup..."
rm -rfv "$DOCKER_COMMON_RO/consensus" "$DOCKER_COMMON_RO/valopers"

echoInfo "INFO: Restarting firewall settings..."
$KIRA_MANAGER/networking.sh

echoInfo "INFO: Loading secrets & generating mnemonics..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

echoInfo "INFO: Recreating docker networks..."
if [ "$KIRA_DOCEKR_NETWORK" != "bridge" ] && [ "$KIRA_DOCEKR_NETWORK" != "host" ] ; then
    MTU=$(cat /sys/class/net/$IFACE/mtu || echo "1500")
    (! $(isNaturalNumber $MTU)) && MTU=1500
    (($MTU < 100)) && MTU=900
    echoInfo "INFO: Recreating $KIRA_DOCEKR_NETWORK network with '$KIRA_DOCEKR_SUBNET' subnet..."
    docker network rm $KIRA_DOCEKR_NETWORK || echoWarn "WARNING: Failed to remove $KIRA_DOCEKR_NETWORK network"
    NETWORKS=$(timeout 10 docker network ls --format="{{.Name}}" || docker network ls --format="{{.Name}}" || echo -n "")
    for net in $NETWORKS ; do
        SUBNET=$(timeout 10 docker network inspect $net | jsonParse "[0].IPAM.Config.[0].Subnet" 2> /dev/null || echo -n "")
        if [ ! -z "$SUBNET" ] && [ "$SUBNET" == "$KIRA_DOCEKR_SUBNET" ] ; then
            echoInfo "INFO: Found network '$net' with overlapping subnet '$KIRA_DOCEKR_SUBNET', attempting to remove..."
            docker network rm $net || echoWarn "WARNING: Failed to remove $net network"
        fi
    done
    docker network create --opt com.docker.network.driver.mtu=$MTU --subnet="$KIRA_DOCEKR_SUBNET" $KIRA_DOCEKR_NETWORK
fi

$KIRA_MANAGER/launch/update-ifaces.sh

echoInfo "INFO: Updating IP addresses info..."
systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )
i=0 && globDel PUBLIC_IP LOCAL_IP
while ( (! $(isIp $(globGet LOCAL_IP))) && (! $(isPublicIp $(globGet PUBLIC_IP))) ) ; do
    i=$((i + 1))
    [ "$i" == "30" ] && echoErr "ERROR: Public IPv4 ($(globGet PUBLIC_IP)) or Local IPv4 ($(globGet LOCAL_IP)) address could not be found. Setup CAN NOT continue!" && exit 1 
    echoInfo "INFO: Waiting for public and local IPv4 address to be updated..."
    sleep 10
done

echoInfo "INFO: Setting up snapshots and geesis file..."
DOCKER_SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.tar"
rm -fv $DOCKER_SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    ln -fv "$KIRA_SNAP_PATH" "$DOCKER_SNAP_DESTINATION"
else
    echoWarn "WARNING: Snapshot file '$KIRA_SNAP_PATH' was NOT found, slow sync will be performed!"
fi

echoInfo "INFO: Setting up essential environment variables..."
if [ "$(globGet INFRA_MODE)" == "seed" ] ; then
    EXTERNAL_SYNC="true"
elif [ "$(globGet INFRA_MODE)" == "sentry" ] ; then
    EXTERNAL_SYNC="true"
elif [ "$(globGet INFRA_MODE)" == "validator" ] ; then
    if [ "$(globGet NEW_NETWORK)" == "true" ] || ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) ) ; then
        EXTERNAL_SYNC="false" 
    else
        EXTERNAL_SYNC="true"
    fi
else
  echoErr "ERROR: Unrecognized infra mode $(globGet INFRA_MODE)"
  exit 1
fi

[ "${EXTERNAL_SYNC,,}" == "false" ] && echoInfo "INFO: Nodes will be synced from the pre-generated genesis in the '$(globGet INFRA_MODE)' mode"
[ "${EXTERNAL_SYNC,,}" == "true" ] && echoInfo "INFO: Nodes will be synced from the external seed node in the '$(globGet INFRA_MODE)' mode"

globSet EXTERNAL_SYNC "$EXTERNAL_SYNC"
globSet KIRA_SETUP_VER "$KIRA_SETUP_VER"

globSet EXTERNAL_SYNC "$EXTERNAL_SYNC" $GLOBAL_COMMON_RO
globSet KIRA_SETUP_VER "$KIRA_SETUP_VER" $GLOBAL_COMMON_RO

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CLEANUP SCRIPT                      |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x