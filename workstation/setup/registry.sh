#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &>/dev/null

CONTAINER_REACHABLE="True"
curl --max-time 3 "$KIRA_REGISTRY/v2/_catalog" || CONTAINER_REACHABLE="False"

# ensure docker registry exists
SETUP_CHECK="$KIRA_SETUP/registry-v0.0.14-$KIRA_REGISTRY_IP-$KIRA_REGISTRY_NAME"
if [[ $(${KIRA_SCRIPTS}/container-exists.sh "registry") != "True" ]] || [ ! -f "$SETUP_CHECK" ] || [ "$CONTAINER_REACHABLE" == "False" ]; then
    echo "Container 'registry' does NOT exist or update is required, creating..."

    ${KIRA_SCRIPTS}/container-delete.sh "registry"
    docker network rm regnet || echo "Failed to remove registry network"
    docker network create \
        --driver=bridge \
        --subnet=10.0.0.0/16 \
        --gateway=10.0.0.1 \
        regnet

    docker run -d \
        --net=regnet \
        --ip 10.0.0.2 \
        --restart=always \
        --name registry \
        -e REGISTRY_STORAGE_DELETE_ENABLED=true \
        -e REGISTRY_LOG_LEVEL=debug \
        registry:2.7.1 # --hostname $KIRA_REGISTRY_NAME \

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "insecure-registries" : ["http://$KIRA_REGISTRY_NAME:$KIRA_REGISTRY_PORT","$KIRA_REGISTRY_NAME:$KIRA_REGISTRY_PORT","http://$KIRA_REGISTRY_IP:$KIRA_REGISTRY_PORT","$KIRA_REGISTRY_IP:$KIRA_REGISTRY_PORT"]
}
EOL
    systemctl restart docker
    touch $SETUP_CHECK
else
    echo "Container 'registry' already exists."
    docker exec -i registry bin/registry --version
fi

docker ps # list containers
docker images
