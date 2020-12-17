#!/bin/bash
set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"
set -x

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
