#!/bin/bash
set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

set -x

SKIP_UPDATE=$1
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echo "------------------------------------------------"
echo "|      STARTED: KIRA INFRA DELETE v0.0.1       |"
echo "------------------------------------------------"

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}')
for CONTAINER in $CONTAINERS; do
    $KIRA_SCRIPTS/container-delete.sh $CONTAINER
done

$KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/base-image" "base-image"
$KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/frontend" "frontend"
$KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/interx" "interx"
$KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/sentry" "sentry"
$KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/validator" "validator"

docker stop $(docker ps -qa) || echo "WARNING: Faile to docker stop all processess"
docker rmi -f $(docker images -qa) || echo "WARNING: Faile to remove all docker images"
docker system prune -a -f || echo "WARNING: Docker prune failed"
docker volume prune -f || echo "WARNING: Failed to prune volumes"

docker network rm servicenet || echo "WARNING: Failed to remove service network"
docker network rm sentrynet || echo "WARNING: Failed to remove sentry network"
docker network rm kiranet || echo "WARNING: Failed to remove kira network"
docker network rm regnet || echo "WARNING: Failed to remove registry network"
docker network prune -f || echo "WARNING: Failed to prune all networks"

echo "------------------------------------------------"
echo "|      FINISHED: KIRA INFRA DELETE v0.0.1      |"
echo "------------------------------------------------"
