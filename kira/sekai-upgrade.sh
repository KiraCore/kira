#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="/common/sekai-upgrade.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Staring container upgrade sequence..."
LOCAL_SEEDS_PATH="$SEKAID_HOME/config/seeds"
PUBLIC_SEEDS="$COMMON_DIR/seeds"
ADDRBOOK_FILE="$SEKAID_HOME/config/addrbook.json"
ADDRBOOK_EXPORT="$SEKAID_HOME/addrbook-export.json"
STATE_FILE="$SEKAID_HOME/data/priv_validator_state.json"
STATE_EXPORT="$SEKAID_HOME/priv_validator_state-export.json"

STATE_HEIGHT=$(jsonParse "height" $STATE_FILE || echo "") && (! $(isNaturalNumber $STATE_HEIGHT)) && STATE_HEIGHT=0

echoInfo "INFO: Exporting configuration files..."
# ensure address book exists or is copied from one of the possible source paths
[ ! -f $ADDRBOOK_EXPORT ] && cp -fv $ADDRBOOK_FILE $ADDRBOOK_EXPORT
[ ! -f $ADDRBOOK_FILE ] && cp -fv $ADDRBOOK_EXPORT $ADDRBOOK_FILE
[ ! -f $STATE_EXPORT ] && cp -fv $STATE_FILE $STATE_EXPORT

echoInfo "INFO: Exporting seeds from address book..."
SEEDS_DUMP="/tmp/seedsdump"
ADDR_DUMP="/tmp/addrdump"
ADDR_DUMP_ARR="/tmp/addrdumparr"
ADDR_DUMP_BASE64="/tmp/addrdump64"
rm -fv $ADDR_DUMP $ADDR_DUMP_ARR $ADDR_DUMP_BASE64 $SEEDS_DUMP
touch $ADDR_DUMP $SEEDS_DUMP $PUBLIC_SEEDS $LOCAL_SEEDS_PATH

jsonParse "addrs" $ADDRBOOK_FILE $ADDR_DUMP_ARR
(jq -rc '.[] | @base64' $ADDR_DUMP_ARR 2> /dev/null || echo -n "") > $ADDR_DUMP_BASE64

while IFS="" read -r row || [ -n "$row" ] ; do
    jobj=$(echo ${row} | base64 --decode 2> /dev/null 2> /dev/null || echo -n "")
    last_success=$(echo "$jobj" | jsonParse "last_success" 2> /dev/null || echo -n "") && last_success=$(delWhitespaces $last_success | tr -d '"' || "")
    ( [ -z "$last_success" ] || [ "$last_success" == "0001-01-01T00:00:00Z" ] ) && echoInfo "INFO: Skipping address, connection was never establised." && continue
    nodeId=$(echo "$jobj" | jsonQuickParse "id" 2> /dev/null || echo -n "") && nodeId=$(delWhitespaces $nodeId | tr -d '"' || "")
    (! $(isNodeId "$nodeId")) && echoInfo "INFO: Skipping address, node id '$nodeId' is invalid." && continue
    ip=$(echo "$jobj" | jsonQuickParse "ip" 2> /dev/null || echo -n "") && ip=$(delWhitespaces $ip | tr -d '"' || "")
    (! $(isIp "$ip")) && echoInfo "INFO: Skipping address, node ip '$ip' is NOT a valid IPv4." && continue
    port=$(echo "$jobj" | jsonQuickParse "port" 2> /dev/null || echo -n "") && port=$(delWhitespaces $port | tr -d '"' || "")
    (! $(isPort "$port")) && echoInfo "INFO: Skipping address, '$port' is NOT a valid port." && continue
    if grep -q "$nodeId" "$SEEDS_DUMP" || grep -q "$ip:$port" "$SEEDS_DUMP" || grep -q "$nodeId" "$PUBLIC_SEEDS" || grep -q "$ip:$port" "$PUBLIC_SEEDS" ; then
        echoWarn "WARNING: Address '$nodeId@$ip:$port' is already present in the seeds list or invalid, last conn ($last_success)"
    else
        echoInfo "INFO: Success, found new node addess '$nodeId@$ip:$port', last conn ($last_success)"
        echo "$nodeId@$ip:$port" >> $SEEDS_DUMP
    fi
done < $ADDR_DUMP_BASE64

cat $PUBLIC_SEEDS >> $SEEDS_DUMP
cat $LOCAL_SEEDS_PATH >> $SEEDS_DUMP
sed -i '/^$/d' $SEEDS_DUMP
sort -u $SEEDS_DUMP -o $SEEDS_DUMP

if (! $(isFileEmpty $SEEDS_DUMP)) ; then
    echoInfo "INFO: New public seed nodes were found in the address book. Saving addressess to LOCAL_SEEDS_PATH '$LOCAL_SEEDS_PATH'..."
    cat $SEEDS_DUMP > $LOCAL_SEEDS_PATH
else
    echoWarn "WARNING: NO new public seed nodes were found in the address book!"
fi

if [ "$UPGRADE_MODE" == "soft" ] ; then
    echoInfo "INFO: Soft fork only requires app executable upgrade."
elif [ "$UPGRADE_MODE" == "hard" ] ; then
    echoInfo "INFO: Converting genesis file..."
    sekaid unsafe-reset-all --home=$SEKAID_HOME
    rm -fv "$SEKAID_HOME/new-genesis.json" "$SEKAID_HOME/config/genesis.json" 
    sekaid new-genesis-from-exported $SEKAID_HOME/genesis-export.json $SEKAID_HOME/new-genesis.json

    NEXT_CHAIN_ID=$(jsonParse "app_state.upgrade.current_plan.new_chain_id" $SEKAID_HOME/new-genesis.json)
    NEW_NETWORK_NAME=$(jsonParse "chain_id" $SEKAID_HOME/new-genesis.json 2> /dev/null || echo -n "")
    ($(isNullOrEmpty $NEW_NETWORK_NAME)) && echoErr "ERROR: Could NOT identify new network name in the exported genesis file" && sleep 10 && exit 1
    [ "$NEW_NETWORK_NAME" != "$NETWORK_NAME" ] && echoErr "ERROR: Invalid genesis chain id swap, expected '$NETWORK_NAME', but got '$NEW_NETWORK_NAME'" && sleep 10 && exit 1
    
    echoInfo "INFO: Re-initalizing chain state..."
    cp -fv $SEKAID_HOME/new-genesis.json $SEKAID_HOME/config/genesis.json
    cp -fv $ADDRBOOK_EXPORT $ADDRBOOK_FILE
    cat >$STATE_FILE <<EOL
{
  "height": "$STATE_HEIGHT",
  "round": 0,
  "step": 0
}
EOL
else
    echoErr "ERROR: Unknown upgrade mode '$UPGRADE_MODE'"
    exit 1
fi

echoInfo "INFO: Finished container upgrade sequence..."
# jsonParse "chain_id" $SEKAID_HOME/config/genesis.json