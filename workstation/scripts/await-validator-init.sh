#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

GENESIS_SOURCE=$1
VALIDATOR_NODE_ID=$2

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
IS_STARTED="false"
NODE_ID=""
PREVIOUS_HEIGHT=0
HEIGHT=0
i=0

while [ $i -le 40 ]; do
    i=$((i + 1))

    echoInfo "INFO: Waiting for $CONTAINER_NAME container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME was initialized"
    fi

    # copy genesis from validator only if internal node syncing takes place
    if [ "${NEW_NETWORK,,}" == "true" ] ; then 
        echoInfo "INFO: Attempting to access genesis file of the new network..."
        docker cp -a $CONTAINER_NAME:$GENESIS_SOURCE $LOCAL_GENESIS_PATH || rm -fv $LOCAL_GENESIS_PATH
    fi

    # make sure genesis is present in the destination path
    if [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
        sleep 12
        echoWarn "WARNING: Failed to copy genesis file from $CONTAINER_NAME"
        continue
    else
        echoInfo "INFO: Success, genesis file was copied to $LOCAL_GENESIS_PATH"
    fi

    echoInfo "INFO: Awaiting node status..."
    STATUS=$(docker exec -i "$CONTAINER_NAME" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "")
    NODE_ID=$(echo "$STATUS" | jq -rc '.NodeInfo.id' 2>/dev/null | xargs || echo "")
    ( [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ) && NODE_ID=$(echo "$STATUS" | jq -rc '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ; then
        sleep 12
        echoWarn "WARNING: Status and Node ID is not available"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME node id found: $NODE_ID"
    fi

    echoInfo "INFO: Awaiting first blocks to be synced or produced..."
    HEIGHT=$(echo "$STATUS" | jq -rc '.SyncInfo.latest_block_height' || echo "")
    (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=$(echo "$STATUS" | jq -rc '.sync_info.latest_block_height' || echo "")
    (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
    
    if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
        echoWarn "INFO: Please wait, new blocks are not beeing synced or produced yet!"
        sleep 10
        PREVIOUS_HEIGHT=$HEIGHT
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing or producing new blocks"
        break
    fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
    echoErr "ERROR: Failed to copy genesis file from the $CONTAINER_NAME node"
    exit 1
fi

if [ "$NODE_ID" != "$VALIDATOR_NODE_ID" ]; then
    echoErr "ERROR: Check $CONTAINER_NAME Node id check failed!"
    echoErr "ERROR: Expected '$VALIDATOR_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
fi

if [ "${IS_STARTED,,}" != "true" ] ; then
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
fi

if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
    echoErr "ERROR: $CONTAINER_NAME node failed to start catching up or prodcing new blocks, check node configuration, peers or if seed nodes function correctly."
    exit 1
fi

if [ "${NEW_NETWORK,,}" == "true" ] ; then 
    echoInfo "INFO: New network was launched, attempting to setup essential post-genesis proposals..."
    PERMSET_PERMISSIONS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermCreateSetPermissionsProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq"
    PERMSETVOTE_PERMISSIONS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermVoteSetPermissionProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq"
    PERMSET_UPSERTALIAS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermCreateUpsertTokenAliasProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq"
    PERMSETVOTE_UPSERTALIAS_PROPOSALS="sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=\$PermVoteUpsertTokenAliasProposal --addr=\$VALIDATOR_ADDR --chain-id=\$NETWORK_NAME --fees=100ukex --yes | jq"
    
    PERMSET_PERMISSIONS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSET_PERMISSIONS_PROPOSALS" | jq -rc '.code' || echo "")
    PERMSETVOTE_PERMISSIONS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSETVOTE_PERMISSIONS_PROPOSALS" | jq -rc '.code' || echo "")
    PERMSET_UPSERTALIAS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSET_UPSERTALIAS_PROPOSALS" | jq -rc '.code' || echo "")
    PERMSETVOTE_UPSERTALIAS_PROPOSALS_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $PERMSETVOTE_UPSERTALIAS_PROPOSALS" | jq -rc '.code' || echo "")

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

    VOTE_YES_LAST_PROPOSAL="LAST_PROPOSAL=\$(sekaid query customgov proposals --output json | jq -rc '.proposals | last | .proposal_id') && sekaid tx customgov proposal vote \$LAST_PROPOSAL 1 --from=validator --chain-id=\$NETWORK_NAME --keyring-backend=test --fees=100ukex --yes | jq"
    QUERY_LAST_PROPOSAL="LAST_PROPOSAL=\$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && sekaid query customgov votes \$LAST_PROPOSAL --output json | jq && sekaid query customgov proposal \$LAST_PROPOSAL --output json | jq"

    PROP_UPSERT_KEX_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $KEX_UPSERT" | jq -rc '.code' || echo "")
    PROP_UPSERT_KEX_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jq -rc '.code' || echo "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    PROP_UPSERT_TEST_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $TEST_UPSERT" | jq -rc '.code' || echo "")
    PROP_UPSERT_TEST_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jq -rc '.code' || echo "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    PROP_UPSERT_SAMOLEAN_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $SAMOLEAN_UPSERT" | jq -rc '.code' || echo "")
    PROP_UPSERT_SAMOLEAN_VOTE_RESULT=$(docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL" | jq -rc '.code' || echo "")
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq || echo ""
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    if [ "000000" != "${PROP_UPSERT_KEX_RESULT}${PROP_UPSERT_KEX_VOTE_RESULT}${PROP_UPSERT_TEST_RESULT}${PROP_UPSERT_TEST_VOTE_RESULT}${PROP_UPSERT_SAMOLEAN_RESULT}${PROP_UPSERT_SAMOLEAN_VOTE_RESULT}" ] ; then
        echoErr "ERROR: Failed to vote on one of the initial proposals"
        exit 1
    fi

    echoInfo "INFO: Success, all initial proposals were raised and voted on"
else
    echoInfo "INFO: Vailidaor is joining a new network, no new proposals will be raised"
fi
