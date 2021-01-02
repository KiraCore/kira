#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

REG_NET_NAME="regnet"
CONTAINER_REACHABLE="True"
curl --max-time 3 "$KIRA_REGISTRY/v2/_catalog" || CONTAINER_REACHABLE="False"

# ensure docker registry exists
SETUP_CHECK="$KIRA_SETUP/registry-v0.0.20-$KIRA_REGISTRY_IP-$KIRA_REGISTRY_DNS-$KIRA_REGISTRY_PORT"
if [[ $(${KIRA_SCRIPTS}/container-exists.sh "registry") != "True" ]] || [ ! -f "$SETUP_CHECK" ] || [ "$CONTAINER_REACHABLE" == "False" ]; then
    echo "Container 'registry' does NOT exist or update is required, creating..."

    $KIRA_SCRIPTS/container-delete.sh "registry"
    $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$REG_NET_NAME"

    docker run -d \
        --network "$REG_NET_NAME" \
        --ip $KIRA_REGISTRY_IP \
        --hostname $KIRA_REGISTRY_DNS \
        --restart=always \
        --name registry \
        -e REGISTRY_STORAGE_DELETE_ENABLED=true \
        -e REGISTRY_LOG_LEVEL=debug \
        registry:2.7.1

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "insecure-registries" : ["http://$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT","$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT","http://$KIRA_REGISTRY_IP:$KIRA_REGISTRY_PORT","$KIRA_REGISTRY_IP:$KIRA_REGISTRY_PORT"],
  "iptables": false
}
EOL
    systemctl daemon-reload
    systemctl restart docker || ( journalctl -u docker | tail -n 10 && systemctl restart docker )
    touch $SETUP_CHECK
else
    echo "Container 'registry' already exists."
    docker exec -i registry bin/registry --version
fi

docker ps # list containers
docker images
