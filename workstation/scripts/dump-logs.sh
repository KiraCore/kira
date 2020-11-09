#!/bin/bash

exec 2>&1
set -e
set -x

# Local Update Shortcut:
# (rm -fv $KIRA_WORKSTATION/delete-image.sh) && nano $KIRA_WORKSTATION/delete-image.sh && chmod 777 $KIRA_WORKSTATION/delete-image.sh
# Use Example:
# $KIRA_WORKSTATION/delete-image.sh "$KIRA_INFRA/docker/base-image" "base-image" "latest"

source "/etc/profile" &> /dev/null
if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

NAME=$1
CONTAINER_DUMP="$KIRA_DUMP/${NAME^^}"

echo "------------------------------------------------"
echo "|          STARTED: DUMP LOGS v0.0.1           |"
echo "------------------------------------------------"
echo "| CONTAINER NAME: $NAME"
echo "| CONTAINER DUMP: $CONTAINER_DUMP"
echo "------------------------------------------------"

rm -rfv $CONTAINER_DUMP
mkdir -p $CONTAINER_DUMP
docker cp $NAME:/var/log/journal $CONTAINER_DUMP/journal || echo "WARNING: Failed to dump journal logs"
docker cp $NAME:/self/logs $CONTAINER_DUMP/logs || echo "WARNING: Failed to dump self logs"
docker cp $NAME:/root/.sekaid $CONTAINER_DUMP/sekaid || echo "WARNING: Failed to dump .sekaid config"
docker cp $NAME:/etc/systemd/system $CONTAINER_DUMP/systemd || echo "WARNING: Failed to dump systemd services"
docker cp $NAME:/common $CONTAINER_DUMP/common || echo "WARNING: Failed to dump common directory"
docker inspect $(docker ps --no-trunc -aqf name=$NAME) > $CONTAINER_DUMP/container-inspect.json || echo "WARNING: Failed to inspect container"
docker inspect $(docker ps --no-trunc -aqf name=$NAME) > $CONTAINER_DUMP/printenv.txt || echo "WARNING: Failed to fetch printenv"
docker exec -i $NAME printenv > $CONTAINER_DUMP/printenv.txt || echo "WARNING: Failed to fetch printenv"
docker logs --timestamps --details $(docker inspect --format="{{.Id}}" ${NAME} 2> /dev/null) > $CONTAINER_DUMP/docker-logs.txt || echo "WARNING: Failed to save docker logs"
docker container logs --details --timestamps $(docker inspect --format="{{.Id}}" ${NAME} 2> /dev/null) > $CONTAINER_DUMP/container-logs.txt || echo "WARNING: Failed to save container logs"
systemctl status docker > $CONTAINER_DUMP/docker-status.txt || echo "WARNING: Failed to save docker status info"
chmod -R 666 $CONTAINER_DUMP
echo "INFO: Starting code editor..."
USER_DATA_DIR="/usr/code$CONTAINER_DUMP"
rm -rf $USER_DATA_DIR
mkdir -p $USER_DATA_DIR

echo "------------------------------------------------"
echo "|        FINISHED: DUMP LOGS    v0.0.1         |"
echo "------------------------------------------------"

