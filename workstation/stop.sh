#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &> /dev/null

SKIP_UPDATE=$1
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

$KIRA_SCRIPTS/progress-touch.sh "+1" #1

echo "------------------------------------------------"
echo "|       STARTED: KIRA INFRA STOP v0.0.1        |"
echo "------------------------------------------------"

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)
for CONTAINER in $CONTAINERS ; do
    $KIRA_SCRIPTS/container-stop.sh $CONTAINER
    $KIRA_SCRIPTS/progress-touch.sh "+1"
done

$KIRA_SCRIPTS/progress-touch.sh "+1" #2+CONTAINER_COUNT

echo "------------------------------------------------"
echo "|      FINISHED: KIRA INFRA STOP v0.0.1        |"
echo "------------------------------------------------"
