#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

START_TIME_CONTAINER_AWAIT="$(date -u +%s)"

NAME=$1
TIMEOUT=$2
DELAY=$3

echo "------------------------------------------------"
echo "| STARTED: AWAITING CONTAINER INIT v0.0.1      |"
echo "|-----------------------------------------------"
echo "|    NAME: $NAME"
echo "| TIMEOUT: $TIMEOUT seconds"
echo "|   DELAY: $DELAY seconds"
echo "------------------------------------------------"

TARGET_PASS_FILE="/self/home/success_end"
TARGET_FAIL_FILE="/self/home/failure_start"
DESTINATION="/tmp/$NAME"
SUCCESS="false"
ELAPSED=0
mkdir -p $DESTINATION

while [[ $ELAPSED -le $TIMEOUT ]] && [ "${SUCCESS,,}" == "false" ] ; do
    ELAPSED=$(($(date -u +%s)-$START_TIME_CONTAINER_AWAIT))
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh $NAME || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true"  ] ; then
        continue
    fi

    SUCCESS="true"
    ERROR="true"
    docker cp $NAME:$TARGET_PASS_FILE "$DESTINATION/tmp-pass.file" &> /dev/null || SUCCESS="false"
    docker cp $NAME:$TARGET_FAIL_FILE "$DESTINATION/tmp-fail.file" &> /dev/null || ERROR="false"

    if [ "${ERROR,,}" == "true" ] ; then
        echo "ERROR: Fail report file was found wihtin container $NAME after $ELAPSED seconds"
        exit 1
    fi

    echo "INFO: Please wait, inspecting container..."
    sleep $DELAY
done

if [ "${SUCCESS,,}" == "false" ] ; then
    echo "ERROR: Awaitng for container $NAME to init, timeouted after $ELAPSED seconds"
    exit 1
fi

echo "------------------------------------------------"
echo "| FINISHED: AWAITING CONTAINER INIT v0.0.1     |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME_CONTAINER_AWAIT)) seconds"
echo "------------------------------------------------"
