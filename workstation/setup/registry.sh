#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/setup/registry.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

REGISTRY_VERSION="2.7.1"
CONTAINER_NAME="registry"
CONTAINER_REACHABLE="true"
curl --fail --max-time 3 "$KIRA_REGISTRY/v2/_catalog" || CONTAINER_REACHABLE="false"

ID=$($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME" || echo -n "")
IP=$(docker inspect $ID | jsonParse "[0].NetworkSettings.Networks.$KIRA_REGISTRY_NETWORK.IPAddress" || echo -n "")
CONTAINER_EXISTS=$(${KIRA_SCRIPTS}/container-exists.sh $CONTAINER_NAME || echo -n "")

# ensure docker registry exists 
ESSENTIALS_HASH=$(echo "$REGISTRY_VERSION-$CONTAINER_NAME-$KIRA_REGISTRY_DNS-$KIRA_REGISTRY_PORT-$KIRA_REGISTRY_NETWORK-$KIRA_HOME-" | md5sum | awk '{ print $1 }' || echo -n "")
SETUP_CHECK="$KIRA_SETUP/registry-2-$ESSENTIALS_HASH" 

if [ "$CONTAINER_EXISTS" != "true" ] || [ ! -f "$SETUP_CHECK" ] || [ "${CONTAINER_REACHABLE,,}" == "false" ] || [ -z "$IP" ]  ; then
    echo "Container '$CONTAINER_NAME' does NOT exist or update is required, creating..."

    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"
    $KIRAMGR_SCRIPTS/restart-networks.sh "false" "$KIRA_REGISTRY_NETWORK"

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

    $KIRA_MANAGER/scripts/update-ifaces.sh

    sleep 1
    ID=$($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME" || echo -n "")
    IP=$(docker inspect $ID | jsonParse "[0].NetworkSettings.Networks.$KIRA_REGISTRY_NETWORK.IPAddress" || echo -n "")

    if [ -z "$IP" ] || [ "${IP,,}" == "null" ] ; then
        echo "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
        exit 1
    fi

    echo "INFO: IP Address $IP found, binding host..."
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

    $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_REGISTRY_NETWORK"
    $KIRA_MANAGER/scripts/update-ifaces.sh
    touch $SETUP_CHECK
else
    echo "Container 'registry' already exists."
    docker exec -i registry bin/registry --version
fi

docker ps # list containers
docker images
