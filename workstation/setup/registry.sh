#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

CONTAINER_NAME="registry"
CONTAINER_REACHABLE="True"
curl --max-time 3 "$KIRA_REGISTRY/v2/_catalog" || CONTAINER_REACHABLE="False"

# ensure docker registry exists
SETUP_CHECK="$KIRA_SETUP/registry-v0.0.20-$CONTAINER_NAME-$KIRA_REGISTRY_DNS-$KIRA_REGISTRY_PORT-$KIRA_REGISTRY_NETWORK"
if [[ $(${KIRA_SCRIPTS}/container-exists.sh "$CONTAINER_NAME") != "True" ]] || [ ! -f "$SETUP_CHECK" ] || [ "$CONTAINER_REACHABLE" == "False" ]; then
    echo "Container '$CONTAINER_NAME' does NOT exist or update is required, creating..."

    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"
    $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_REGISTRY_NETWORK"

    docker run -d \
        --network "$KIRA_REGISTRY_NETWORK" \
        --hostname $KIRA_REGISTRY_DNS \
        --restart=always \
        --name $CONTAINER_NAME \
        -e REGISTRY_STORAGE_DELETE_ENABLED=true \
        -e REGISTRY_LOG_LEVEL=debug \
        registry:2.7.1

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "insecure-registries" : ["http://$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT","$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT"],
  "iptables": false
}
EOL
    systemctl daemon-reload
    systemctl restart docker || ( journalctl -u docker | tail -n 10 && systemctl restart docker )

    ID=$(docker inspect --format="{{.Id}}" $CONTAINER_NAME || echo "")
    IP=$(docker inspect $ID | jq -r ".[0].NetworkSettings.Networks.$KIRA_REGISTRY_NETWORK.IPAddress" | xargs || echo "")
    
    if [ -z "$IP" ] || [ "${IP,,}" == "null" ] ; then
        echo "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
        exit 1
    fi
    
    echo "INFO: IP Address found, binding host..."
    CDHelper text lineswap --insert="$IP $KIRA_REGISTRY_DNS" --regex="$KIRA_REGISTRY_DNS" --path=$HOSTS_PATH --prepend-if-found-not=True

    touch $SETUP_CHECK
else
    echo "Container 'registry' already exists."
    docker exec -i registry bin/registry --version
fi

docker ps # list containers
docker images
