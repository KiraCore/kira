#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

VALIDATOR_NODE_ID=$1

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
IS_STARTED="false"
IFACES_RESTARTED="false"
RPC_PORT="KIRA_${CONTAINER_NAME^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"
TIMER_NAME="${CONTAINER_NAME^^}_INIT"
TIMEOUT=3600

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING ${CONTAINER_NAME^^} INIT $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| COMMON DIR: $COMMON_PATH"
echoWarn "|    TIMEOUT: $TIMEOUT seconds"
echoWarn "|   RPC PORT: $RPC_PORT"
echoWarn "|-------------------------------------------------"
set -x

NODE_ID=""
PREVIOUS_HEIGHT=0
HEIGHT=0

globDel "${CONTAINER_NAME}_STATUS" "${CONTAINER_NAME}_EXISTS"
timerStart $TIMER_NAME

systemctl restart kirascan || echoWarn "WARNING: Could NOT restart kira scan service"

while [[ $(timerSpan $TIMER_NAME) -lt $TIMEOUT ]] ; do

    echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
    if [ "$(globGet ${CONTAINER_NAME}_EXISTS)" != "true" ] ; then
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
    else echoInfo "INFO: Success, container $CONTAINER_NAME was found" ; fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
        cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME was initialized" ; fi

    # copy genesis from validator only if internal node syncing takes place
    if [ "${NEW_NETWORK,,}" == "true" ] ; then 
        echoInfo "INFO: Attempting to access genesis file of the new network..."
        chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
        rm -fv $LOCAL_GENESIS_PATH
        cp -afv "$COMMON_PATH/genesis.json" "$LOCAL_GENESIS_PATH" || rm -fv $LOCAL_GENESIS_PATH
    fi

    # make sure genesis is present in the destination path
    if [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
        echoWarn "WARNING: Failed to copy genesis file from $CONTAINER_NAME, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 12 && continue
    else
        chattr +i "$LOCAL_GENESIS_PATH"
        echoInfo "INFO: Success, genesis file was copied to $LOCAL_GENESIS_PATH"
    fi

    echoInfo "INFO: Awaiting node status..."
    STATUS=$(timeout 6 curl 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") 
    NODE_ID=$(echo "$STATUS" | jsonQuickParse "id" || echo -n "")
    if (! $(isNodeId "$NODE_ID")); then
        echoWarn "WARNING: Status and Node ID is not available, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 12 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME node id found: $NODE_ID" ; fi

    echoInfo "INFO: Awaiting first blocks to be synced or produced..."
    HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" || echo -n "")
    (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
    
    if [[ $HEIGHT -le $PREVIOUS_HEIGHT ]] ; then
        echoWarn "INFO: New blocks are not beeing synced or produced yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 10 && PREVIOUS_HEIGHT=$HEIGHT && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing or producing new blocks" && break ; fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

[ ! -f "$LOCAL_GENESIS_PATH" ] && \
    echoErr "ERROR: Failed to copy genesis file from the $CONTAINER_NAME node" && exit 1

[ "$NODE_ID" != "$VALIDATOR_NODE_ID" ] && \
    echoErr "ERROR: Container $CONTAINER_NAME Node Id check failed! Expected '$VALIDATOR_NODE_ID', but got '$NODE_ID'" && exit 1

[ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] && \
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time" && exit 1

[[ $HEIGHT -le $PREVIOUS_HEIGHT ]] && \
    echoErr "ERROR: $CONTAINER_NAME node failed to start catching up or prodcing new blocks, check node configuration, peers or if seed nodes function correctly." && exit 1

if [ "${NEW_NETWORK,,}" == "true" ] ; then 
    echoInfo "INFO: New network was launched, attempting to setup essential post-genesis proposals..."
    PERMSET_PERMISSIONS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermCreateSetPermissionsProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --gas=1000000000 --yes | jq"
    PERMSETVOTE_PERMISSIONS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermVoteSetPermissionProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --gas=1000000000 --yes | jq"
    PERMSET_UPSERTALIAS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermCreateUpsertTokenAliasProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --gas=1000000000 --yes | jq"
    PERMSETVOTE_UPSERTALIAS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermVoteUpsertTokenAliasProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --gas=1000000000 --yes | jq"
    
    PERMSET_PERMISSIONS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSET_PERMISSIONS_PROPOSALS" | jsonParse "code" || echo -n "")
    PERMSETVOTE_PERMISSIONS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSETVOTE_PERMISSIONS_PROPOSALS" | jsonParse "code" || echo -n "")
    PERMSET_UPSERTALIAS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSET_UPSERTALIAS_PROPOSALS" | jsonParse "code" || echo -n "")
    PERMSETVOTE_UPSERTALIAS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSETVOTE_UPSERTALIAS_PROPOSALS" | jsonParse "code" || echo -n "")

    if [ "0000" != "${PERMSET_PERMISSIONS_PROPOSALS_RESULT}${PERMSETVOTE_PERMISSIONS_PROPOSALS_RESULT}${PERMSET_UPSERTALIAS_PROPOSALS_RESULT}${PERMSETVOTE_UPSERTALIAS_PROPOSALS_RESULT}" ] ; then
        echoErr "ERROR: One of the permission assignments failed"
        exit 1
    fi

    echoInfo "INFO: Creating initial upsert token aliases proposals and voting on them..."

    KEX_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="KEX" \
 --name="KIRA" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg" \
 --decimals=6 \
 --denoms="ukex" \
 --description="Upsert KEX icon URL link" \
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq
EOL
)

    TEST_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="TEST" \
 --name="Test TestCoin" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/test.svg" \
 --decimals=8 \
 --denoms="test" \
 --description="Upsert Test TestCoin icon URL link" \
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq
EOL
)

    SAMOLEAN_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="SAMOLEAN" \
 --name="Samolean TestCoin" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/samolean.svg" \
 --decimals=18 \
 --denoms="samolean" \
 --description="Upsert Samolean TestCoin icon URL link" \
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq
EOL
)

    VOTE_YES_LAST_PROPOSAL="voteYes \$(lastProposal) validator"
    QUERY_LAST_PROPOSAL="showProposal \$(lastProposal)"

    PROP_UPSERT_KEX_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $KEX_UPSERT" | jsonQuickParse "code" || echo -n "")
    sleep 10
    PROP_UPSERT_KEX_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jsonQuickParse "code" || echo -n "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo -n ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    PROP_UPSERT_TEST_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $TEST_UPSERT" | jsonQuickParse "code" || echo -n "")
    sleep 10
    PROP_UPSERT_TEST_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jsonQuickParse "code" || echo -n "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo -n ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    PROP_UPSERT_SAMOLEAN_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $SAMOLEAN_UPSERT" | jsonQuickParse "code" || echo -n "")
    sleep 10
    PROP_UPSERT_SAMOLEAN_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jsonQuickParse "code" || echo -n "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo -n ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    if [ "000000" != "${PROP_UPSERT_KEX_RESULT}${PROP_UPSERT_KEX_VOTE_RESULT}${PROP_UPSERT_TEST_RESULT}${PROP_UPSERT_TEST_VOTE_RESULT}${PROP_UPSERT_SAMOLEAN_RESULT}${PROP_UPSERT_SAMOLEAN_VOTE_RESULT}" ] ; then
        echoErr "ERROR: Failed to vote on one of the initial proposals"
        exit 1
    fi

    echoInfo "INFO: Success, all initial proposals were raised and voted on"
else
    echoInfo "INFO: Vailidaor is joining a new network, no new proposals will be raised"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: ${CONTAINER_NAME^^} INIT"
echoWarn "|  ELAPSED: $(timerSpan $TIMER_NAME) seconds"
echoWarn "------------------------------------------------"
set -x