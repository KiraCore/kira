#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

SKIP_UPDATE=$1
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echo "------------------------------------------------"
echo "|      STARTED: KIRA INFRA DELETE v0.0.1       |"
echo "------------------------------------------------"

$KIRA_SCRIPTS/progress-touch.sh "+1" #1

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}')
for CONTAINER in $CONTAINERS; do
    $KIRA_SCRIPTS/container-delete.sh $CONTAINER
    $KIRA_SCRIPTS/progress-touch.sh "+1" #+CONTAINER_COUNT
done

$KIRA_SCRIPTS/progress-touch.sh "+1" #2

$WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/base-image" "base-image"
$WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/frontend-image" "frontend-image"
$WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/kms-image" "kms-image"
$WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/sentry-image" "sentry-image"
$WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/validator" "validator"

docker stop $(docker ps -qa) || echo "WARNING: Faile to docker stop all processess"
docker rmi -f $(docker images -qa) || echo "WARNING: Faile to remove all docker images"
docker system prune -a -f || echo "WARNING: Docker prune failed"
docker volume prune -f || echo "WARNING: Failed to prune volumes"

$KIRA_SCRIPTS/progress-touch.sh "+1" #6

docker network rm validatornet || echo "WARNING: Failed to remove kira network"
docker network rm regnet || echo "WARNING: Failed to remove registry network"
docker network prune -f || echo "WARNING: Failed to prune all networks"

$KIRA_SCRIPTS/progress-touch.sh "+1" #7+CONTAINER_COUNT

echo "------------------------------------------------"
echo "|      FINISHED: KIRA INFRA DELETE v0.0.1      |"
echo "------------------------------------------------"
