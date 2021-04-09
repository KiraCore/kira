#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-valinfo.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALOPERS_SCAN_PATH="$SCAN_DIR/valopers"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
VALINFO_SCAN_PATH="$SCAN_DIR/valinfo"
CONSENSUS_SCAN_PATH="$SCAN_DIR/consensus"

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA VALIDATORS SCAN          |"
echoWarn "|-----------------------------------------------"
echoWarn "|   VALINFO_SCAN_PATH: $VALINFO_SCAN_PATH"
echoWarn "| VALSTATUS_SCAN_PATH: $VALSTATUS_SCAN_PATH"
echoWarn "|  VALOPERS_SCAN_PATH: $VALOPERS_SCAN_PATH"
echoWarn "|   VALADDR_SCAN_PATH: $VALADDR_SCAN_PATH"
echoWarn "| CONSENSUS_SCAN_PATH: $CONSENSUS_SCAN_PATH"
echoWarn "------------------------------------------------"
set -x

touch "$VALADDR_SCAN_PATH" "$VALSTATUS_SCAN_PATH" "$VALOPERS_SCAN_PATH" "$VALINFO_SCAN_PATH"

echo "INFO: Saving valopers info..."
VALOPERS=$(timeout 60 curl "0.0.0.0:$KIRA_INTERX_PORT/api/valopers?all=true" | jq -rc '.' || echo "")
CONSENSUS=$(timeout 60 curl "0.0.0.0:$KIRA_INTERX_PORT/api/consensus" | jq -rc '.' || echo "")
WAITING=$(echo $VALOPERS | jq '.waiting' || echo "" )
echo "$VALOPERS" > $VALOPERS_SCAN_PATH
echo "$CONSENSUS" > $CONSENSUS_SCAN_PATH

# let containers know the validators info
echo "$VALOPERS" > "$DOCKER_COMMON_RO/valopers"
echo "$CONSENSUS" > "$DOCKER_COMMON_RO/consensus"

if [[ "${INFRA_MODE,,}" =~ ^(validator|local)$ ]] ; then
    echo "INFO: Validator info will the scanned..."
else
    echo "" > $VALINFO_SCAN_PATH
    echo "" > $VALADDR_SCAN_PATH
    echo "" > $VALSTATUS_SCAN_PATH
    exit 0
fi

VALSTATUS=""
VALADDR=$(docker exec -i validator sekaid keys show validator -a --keyring-backend=test || echo "")
if [ ! -z "$VALADDR" ] && [[ $VALADDR == kira* ]] ; then
    echo "$VALADDR" > $VALADDR_SCAN_PATH
else
    VALADDR=$(cat $VALADDR_SCAN_PATH || echo "")
fi

if [ ! -z "$VALADDR" ] && [[ $VALADDR == kira* ]] ; then
    VALSTATUS=$(docker exec -i validator sekaid query validator --addr=$VALADDR --output=json | jq -rc '.' || echo "")
else
    VALSTATUS=""
fi

if [ -z "$VALSTATUS" ] ; then
    echo "ERROR: Validator address or status was not found"
    if [ ! -z "$VALADDR" ] && [ ! -z "$WAITING" ] && [[ $WAITING =~ "$VALADDR" ]]; then
        echo "{ \"status\": \"WAITING\" }" > $VALSTATUS_SCAN_PATH
    else
        echo "" > $VALSTATUS_SCAN_PATH
    fi
else
    echo "$VALSTATUS" > $VALSTATUS_SCAN_PATH
fi

VALOPER_FOUND="false"
VALIDATORS=$(echo $VALOPERS 2> /dev/null | jq -rc '.validators' 2> /dev/null || echo "")
if [ -z "$VALIDATORS" ] ; then
    echo "INFO: Failed to querry velopers info"
    echo "" > $VALINFO_SCAN_PATH
else
    for row in $(echo "$VALIDATORS" 2> /dev/null | jq -rc '.[] | @base64' 2> /dev/null || echo ""); do
        vobj=$(echo ${row} | base64 --decode 2> /dev/null | jq -rc 2> /dev/null || echo "")
        vaddr=$(echo "$vobj" 2> /dev/null | jq -rc '.address' 2> /dev/null || echo "")
        if [ "$VALADDR" == "$vaddr" ] ; then
            echo "$vobj" > $VALINFO_SCAN_PATH
            VALOPER_FOUND="true"
            break
        fi
    done
fi

if [ "${VALOPER_FOUND,,}" != "true" ] ; then
    echo "INFO: Validator '$VALADDR' was not found in the valopers querry"
    echo "" > $VALINFO_SCAN_PATH
    exit 0
fi

sleep 5

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: VALIDATORS MONITOR                 |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x