#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-valinfo.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

SCRIPT_START_TIME="$(date -u +%s)"
VALIDATORS64_SCAN_PATH="$KIRA_SCAN/validators64"
VALSTATUS_SCAN_PATH="$KIRA_SCAN/valstatus"
VALINFO_SCAN_PATH="$KIRA_SCAN/valinfo"

NETPROPS_SCAN_PATH="$KIRA_SCAN/netprops"
VALOPERS_SCAN_PATH="$KIRA_SCAN/valopers"
CONSENSUS_SCAN_PATH="$KIRA_SCAN/consensus"
VALIDATORS_SCAN_PATH="$KIRA_SCAN/validators"
VALOPERS_COMM_RO_PATH="$DOCKER_COMMON_RO/valopers"
CONSENSUS_COMM_RO_PATH="$DOCKER_COMMON_RO/consensus"
NETPROPS_COMM_RO_PATH="$DOCKER_COMMON_RO/netprops"

INFRA_MODE=$(globGet INFRA_MODE)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA VALIDATORS SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|          INFRA_MODE: $(globGet INFRA_MODE)"
echoWarn "|   VALINFO_SCAN_PATH: $VALINFO_SCAN_PATH"
echoWarn "| VALSTATUS_SCAN_PATH: $VALSTATUS_SCAN_PATH"
echoWarn "|  VALOPERS_SCAN_PATH: $VALOPERS_SCAN_PATH"
echoWarn "| CONSENSUS_SCAN_PATH: $CONSENSUS_SCAN_PATH"
echoWarn "|  NETPROPS_SCAN_PATH: $NETPROPS_SCAN_PATH"
echoWarn "------------------------------------------------"
set -x

sleep 1
touch "$VALSTATUS_SCAN_PATH" "$VALOPERS_SCAN_PATH" "$VALINFO_SCAN_PATH"

echoInfo "INFO: Saving valopers info..."
(curl --fail "0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/api/valopers?all=true" || echo -n "") > $VALOPERS_SCAN_PATH
(curl --fail "0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/api/consensus" || echo -n "") > $CONSENSUS_SCAN_PATH
(curl --fail "0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/api/kira/gov/network_properties" || echo -n "") > $NETPROPS_SCAN_PATH

# let containers know the validators info
($(isSimpleJsonObjOrArrFile "$VALOPERS_SCAN_PATH")) && cp -afv "$VALOPERS_SCAN_PATH" "$VALOPERS_COMM_RO_PATH" || echo -n "" > "$VALOPERS_COMM_RO_PATH"
($(isSimpleJsonObjOrArrFile "$CONSENSUS_SCAN_PATH")) && cp -afv "$CONSENSUS_SCAN_PATH" "$CONSENSUS_COMM_RO_PATH" || echo -n "" > "$CONSENSUS_COMM_RO_PATH"
($(isSimpleJsonObjOrArrFile "$NETPROPS_SCAN_PATH")) && cp -afv "$NETPROPS_SCAN_PATH" "$NETPROPS_COMM_RO_PATH" || echo -n "" > "$NETPROPS_COMM_RO_PATH"

if [[ "$(globGet INFRA_MODE)" =~ ^(validator)$ ]] ; then
    echoInfo "INFO: Fetching validator address.."
    VALIDATOR_ADDR=$(timeout 30 echo $(docker exec -i validator /bin/bash -c ". /etc/profile;showAddress validator") | xargs || echo -n "")
    ($(isKiraAddress "$VALIDATOR_ADDR")) && globSet VALIDATOR_ADDR "$VALIDATOR_ADDR" || VALIDATOR_ADDR=$(globGet VALIDATOR_ADDR)
else
    echoInfo "INFO: Validator info will NOT be scanned..."
    echo -n "" > $VALINFO_SCAN_PATH
    echo -n "" > $VALSTATUS_SCAN_PATH
    globDel VALIDATOR_ADDR
    VALIDATOR_ADDR=""
fi

echoInfo "INFO: Fetching validator status ($VALIDATOR_ADDR) ..."
VALSTATUS=""
if ($(isKiraAddress "$VALIDATOR_ADDR")) ; then
    VALSTATUS=$(timeout 30 echo "$(docker exec -i validator sekaid query customstaking validator --addr=$VALIDATOR_ADDR --output=json)" | jsonParse "" || echo -n "")
fi

if [ -z "$VALSTATUS" ] ; then
    echoErr "ERROR: Validator address or status was not found, checking waiting list..."
    WAITING=$(jsonParse "waiting" $VALOPERS_COMM_RO_PATH || echo -n "" )
    if [ ! -z "$VALIDATOR_ADDR" ] && [ ! -z "$WAITING" ] && [[ $WAITING =~ "$VALIDATOR_ADDR" ]]; then
        VALSTATUS="{ \"status\": \"WAITING\" }"
    else
        echoErr "ERROR: Validator does NOT have a WAITING status"
    fi
fi

if [ ! -z "$VALSTATUS" ] ; then
    echoInfo "INFO: Validator status was found..."
    echo "$VALSTATUS" > $VALSTATUS_SCAN_PATH
    STATUS="$(toLower "$(echo "$VALSTATUS" | jsonQuickParse "status" || echo -n "")")"
else
    echoInfo "INFO: Validator status was NOT found..."
    echo -n "" > $VALSTATUS_SCAN_PATH
    STATUS=""
fi

if ($(isFileEmpty $VALOPERS_COMM_RO_PATH)) || [ "$STATUS" == "waiting" ] ; then
    echoWarn "WARNING: List of validators was NOT found or validator has WAITING status, aborting info discovery"
    echo -n "" > $VALINFO_SCAN_PATH
else
    echoInfo "INFO: Attempting validator info discovery"
    VALOPER_FOUND="false"
    jsonParse "validators" $VALOPERS_COMM_RO_PATH $VALIDATORS_SCAN_PATH
    (jq -rc '.[] | @base64' $VALIDATORS_SCAN_PATH 2> /dev/null || echo -n "") > $VALIDATORS64_SCAN_PATH

    if ($(isFileEmpty "$VALIDATORS64_SCAN_PATH")) ; then
        echoWarn "WARNING: Failed to querry velopers info"
        echo -n "" > $VALINFO_SCAN_PATH
    else
        while IFS="" read -r row || [ -n "$row" ] ; do
        sleep 0.1
            vobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
            vaddr=$(echo "$vobj" | jsonQuickParse "address" 2> /dev/null || echo -n "")
            if [ "$VALIDATOR_ADDR" == "$vaddr" ] ; then
                echoInfo "INFO: Validator info was found"
                echo "$vobj" > $VALINFO_SCAN_PATH
                VALOPER_FOUND="true"
                break
            fi
        done < $VALIDATORS64_SCAN_PATH
    fi

    if [ "$VALOPER_FOUND" != "true" ] ; then
        echoInfo "INFO: Validator '$VALIDATOR_ADDR' was NOT found in the valopers querry"
        echo -n "" > $VALINFO_SCAN_PATH
    fi
fi

VAL_ACTIVE="$(jsonQuickParse "active_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" 
VAL_TOTAL="$(jsonQuickParse "total_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" 
VAL_WAITING="$(jsonQuickParse "waiting_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" 
CONS_STOPPED="$(jsonQuickParse "consensus_stopped" $CONSENSUS_COMM_RO_PATH 2>/dev/null || echo -n "")" 
CONS_BLOCK_TIME="$(jsonQuickParse "average_block_time" $CONSENSUS_COMM_RO_PATH  2>/dev/null || echo -n "")"
LATEST_BLOCK_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") 
CONS_STOPPED_HEIGHT=$(globGet CONS_STOPPED_HEIGHT)
($(isNullOrEmpty "$VAL_ACTIVE")) && VAL_ACTIVE="???"
($(isNullOrEmpty "$VAL_TOTAL")) && VAL_TOTAL="???"
($(isNullOrEmpty "$VAL_WAITING")) && VAL_WAITING="???"
($(isNullOrEmpty "$CONS_STOPPED")) && CONS_STOPPED="???" 
(! $(isNumber "$CONS_BLOCK_TIME")) && CONS_BLOCK_TIME="???"
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0
(! $(isNaturalNumber "$CONS_STOPPED_HEIGHT")) && CONS_STOPPED_HEIGHT=0

if [ "$CONS_STOPPED_HEIGHT" != "$LATEST_BLOCK_HEIGHT" ] ; then
    CONS_STOPPED="false"
    globSet CONS_STOPPED_HEIGHT "$LATEST_BLOCK_HEIGHT"
fi

globSet VAL_ACTIVE $VAL_ACTIVE
globSet VAL_TOTAL $VAL_TOTAL
globSet VAL_WAITING $VAL_WAITING
globSet CONS_BLOCK_TIME $CONS_BLOCK_TIME
globSet CONS_STOPPED $CONS_STOPPED

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: VALIDATORS MONITOR                 |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
