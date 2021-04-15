#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-valinfo.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALIDATORS64_SCAN_PATH="$SCAN_DIR/validators64"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
VALINFO_SCAN_PATH="$SCAN_DIR/valinfo"

VALOPERS_SCAN_PATH="$SCAN_DIR/valopers"
CONSENSUS_SCAN_PATH="$SCAN_DIR/consensus"
VALIDATORS_SCAN_PATH="$SCAN_DIR/validators"
VALOPERS_COMM_RO_PATH="$DOCKER_COMMON_RO/valopers"
CONSENSUS_COMM_RO_PATH="$DOCKER_COMMON_RO/consensus"

set +x
echoWarn "------------------------------------------------"
echoWarn "|    STARTING KIRA VALIDATORS SCAN v0.2.4.0    |"
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
(timeout 60 curl --fail "0.0.0.0:$KIRA_INTERX_PORT/api/valopers?all=true" || echo -n "") > $VALOPERS_SCAN_PATH
(timeout 60 curl --fail "0.0.0.0:$KIRA_INTERX_PORT/api/consensus" || echo -n "") > $CONSENSUS_SCAN_PATH

# let containers know the validators info
($(isSimpleJsonObjOrArrFile "$VALOPERS_SCAN_PATH")) && cp -afv "$VALOPERS_SCAN_PATH" "$VALOPERS_COMM_RO_PATH" || echo -n "" > "$VALOPERS_COMM_RO_PATH"
($(isSimpleJsonObjOrArrFile "$CONSENSUS_SCAN_PATH")) && cp -afv "$CONSENSUS_SCAN_PATH" "$CONSENSUS_COMM_RO_PATH" || echo -n "" > "$CONSENSUS_COMM_RO_PATH"

if [[ "${INFRA_MODE,,}" =~ ^(validator|local)$ ]] ; then
    echo "INFO: Validator info will the scanned..."
else
    echo -n "" > $VALINFO_SCAN_PATH
    echo -n "" > $VALADDR_SCAN_PATH
    echo -n "" > $VALSTATUS_SCAN_PATH
    exit 0
fi

VALSTATUS=""
VALADDR=$(docker exec -i validator sekaid keys show validator -a --keyring-backend=test | xargs || echo -n "")
if [ ! -z "$VALADDR" ] && [[ $VALADDR == kira* ]] ; then
    echo "$VALADDR" > $VALADDR_SCAN_PATH
else
    VALADDR=$(cat $VALADDR_SCAN_PATH || echo -n "")
fi

if [ ! -z "$VALADDR" ] && [[ $VALADDR == kira* ]] ; then
    VALSTATUS=$(timeout 10 echo "$(docker exec -i validator sekaid query validator --addr=$VALADDR --output=json)" | jsonParse "" || echo -n "")
else
    VALSTATUS=""
fi

if [ -z "$VALSTATUS" ] ; then
    echoErr "ERROR: Validator address or status was not found"
    WAITING=$(jsonParse "waiting" $VALOPERS_COMM_RO_PATH || echo -n "" )
    if [ ! -z "$VALADDR" ] && [ ! -z "$WAITING" ] && [[ $WAITING =~ "$VALADDR" ]]; then
        echo "{ \"status\": \"WAITING\" }" > $VALSTATUS_SCAN_PATH
    else
        echo -n "" > $VALSTATUS_SCAN_PATH
    fi
else
    echo "$VALSTATUS" > $VALSTATUS_SCAN_PATH
fi

VALOPER_FOUND="false"
jsonParse "validators" $VALOPERS_COMM_RO_PATH > $VALIDATORS_SCAN_PATH
(jq -rc '.[] | @base64' $VALIDATORS_SCAN_PATH 2> /dev/null || echo -n "") > $VALIDATORS64_SCAN_PATH

if ($(isFileEmpty "$VALIDATORS64_SCAN_PATH")) ; then
    echoWarn "WARNING: Failed to querry velopers info"
    echo -n "" > $VALINFO_SCAN_PATH
else
    while IFS="" read -r row || [ -n "$row" ] ; do
    sleep 0.1
        vobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
        vaddr=$(echo "$vobj" | jsonQuickParse "address" 2> /dev/null || echo -n "")
        if [ "$VALADDR" == "$vaddr" ] ; then
            echo "$vobj" > $VALINFO_SCAN_PATH
            VALOPER_FOUND="true"
            break
        fi
    done < $VALIDATORS64_SCAN_PATH
fi

if [ "${VALOPER_FOUND,,}" != "true" ] ; then
    echoInfo "INFO: Validator '$VALADDR' was not found in the valopers querry"
    echo -n "" > $VALINFO_SCAN_PATH
    exit 0
fi

sleep 10

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: VALIDATORS MONITOR                 |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
