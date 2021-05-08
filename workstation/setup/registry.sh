#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/setup/registry.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

REGISTRY_VERSION="2.7.1"
CONTAINER_NAME="registry"
CONTAINER_REACHABLE="true"
UPDATE_CHECK_IMAGES="images-build-1-$KIRA_SETUP_VER"
curl --fail --max-time 3 "$KIRA_REGISTRY/v2/_catalog" || CONTAINER_REACHABLE="false"

# ensure docker registry exists 
ESSENTIALS_HASH=$(echo "$REGISTRY_VERSION-$CONTAINER_NAME-$KIRA_REGISTRY_DNS-$KIRA_REGISTRY_PORT-$KIRA_REGISTRY_NETWORK-$KIRA_HOME-" | md5)
SETUP_CHECK="$KIRA_SETUP/registry-2-$ESSENTIALS_HASH" 

if [ ! -f "$SETUP_CHECK" ] || [ "${CONTAINER_REACHABLE,,}" != "true" ] ; then
    echoInfo "INFO: Container '$CONTAINER_NAME' does NOT exist or is not reachable, update is required recreating registry..."

    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"
    #$KIRAMGR_SCRIPTS/restart-networks.sh "false" "$KIRA_REGISTRY_NETWORK"

    network="regnet"
    subnet=$KIRA_REGISTRY_SUBNET
    echoInfo "INFO: Recreating $network network and $subnet subnet..."
    
    FAILED="false"
    timeout 30 docker network rm $network || FAILED="true"
    
    if [ "${FAILED,,}" == "true" ] ; then
        echoWarn "WARNING: Failed to remove $network network"
        $KIRA_MANAGER/scripts/update-ifaces.sh
        $KIRA_SCRIPTS/docker-restart.sh
        timeout 30 docker network rm $network || echoWarn "WARNING: Failed to remove $network network after service restart"
    fi
    
    $KIRA_MANAGER/scripts/update-ifaces.sh
    docker network create --opt com.docker.network.driver.mtu=$(globGet MTU) --subnet=$subnet $network || echoWarn "WARNING: Failed to create $network network"

    echoInfo "INFO: Starting registry container..."
    CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
    RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
    CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
    RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

    docker run -d \
        --cpus="$CPU_RESERVED" \
        --memory="$RAM_RESERVED" \
        --oom-kill-disable \
        --network "$KIRA_REGISTRY_NETWORK" \
        --hostname $KIRA_REGISTRY_DNS \
        --restart=always \
        --name $CONTAINER_NAME \
        --log-opt max-size=5m \
        --log-opt max-file=5 \
        -e REGISTRY_HTTP_ADDR="0.0.0.0:$KIRA_REGISTRY_PORT" \
        -e REGISTRY_STORAGE_DELETE_ENABLED=true \
        -e REGISTRY_LOG_LEVEL=debug \
        registry:$REGISTRY_VERSION

    echoInfo "INFO: Waiting for registry container to start..."
    sleep 30
    
    ID=$($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME" || echo -n "")

    if ($(isNullOrEmpty $ID)) ; then
        echoErr "ERROR: Failed to get ID of the $CONTAINER_NAME container"
        exit 1
    fi

    IP=$(docker inspect $ID | jsonParse "[0].NetworkSettings.Networks.$KIRA_REGISTRY_NETWORK.IPAddress" || echo -n "")

    if ($(isNullOrEmpty $IP)) ; then
        echoErr "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
        exit 1
    fi

    echoInfo "INFO: IP Address $IP found, binding host..."
    CDHelper text lineswap --insert="$IP $KIRA_REGISTRY_DNS" --regex="$KIRA_REGISTRY_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    ADDR1="$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT"
    ADDR2="$IP:$KIRA_REGISTRY_PORT"
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "insecure-registries" : ["http://$ADDR1","http://$ADDR2","$ADDR1","$ADDR2"],
  "iptables": false,
  "storage-driver": "overlay2"
}
EOL

    #$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_REGISTRY_NETWORK"
    $KIRA_MANAGER/scripts/update-ifaces.sh
    rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_IMAGES"
    touch $SETUP_CHECK
else
    echoInfo "INFO: Container 'registry' already exists."
    docker exec -i registry bin/registry --version
fi

docker ps # list containers
docker images
