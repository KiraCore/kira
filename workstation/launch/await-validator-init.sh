#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

EXPECTED_NODE_ID="$1"

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
APP_HOME="$DOCKER_HOME/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
IS_STARTED="false"
IFACES_RESTARTED="false"
TIMER_NAME="${CONTAINER_NAME^^}_INIT"
TIMEOUT=3600

if [ "$(globGet INIT_MODE)" == "upgrade" ] ; then
    [ "$(globGet UPGRADE_INSTATE)" == "true" ] && UPGRADE_MODE="soft" || UPGRADE_MODE="hard"
else
    UPGRADE_MODE="none"
fi

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING ${CONTAINER_NAME^^} INIT $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "|       COMMON DIR: $COMMON_PATH"
echoWarn "|          TIMEOUT: $TIMEOUT seconds"
echoWarn "|         RPC PORT: $(globGet CUSTOM_RPC_PORT)"
echoWarn "| EXPECTED NODE ID: $EXPECTED_NODE_ID"
echoWarn "|        INIT MODE: $(globGet INIT_MODE)"
echoWarn "|     UPGRADE MODE: $UPGRADE_MODE"
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
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" == "setting up" ] ; then
        timerPause $TIMER_NAME
        cat $COMMON_LOGS/start.log | tail -n 200 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
        echoWarn "WARNING: $CONTAINER_NAME is still being configured, please wait ..." && sleep 30 && continue
    else
        timerUnpause $TIMER_NAME
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
        cat $COMMON_LOGS/start.log | tail -n 200 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME was initialized" ; fi

    # copy genesis from validator only if internal node syncing takes place
    if [ "$(globGet NEW_NETWORK)" == "true" ] || [ "$UPGRADE_MODE" == "hard" ] ; then 
        echoInfo "INFO: Attempting to access genesis file of the new network..."
        chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
        chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the reference direcotry"
        rm -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
        cp -afv $APP_HOME/config/genesis.json "$LOCAL_GENESIS_PATH" || rm -fv $LOCAL_GENESIS_PATH
    fi

    # make sure genesis is present in the destination path
    if [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
        echoWarn "WARNING: Failed to copy genesis file from $CONTAINER_NAME, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 12 && continue
    else
        chattr +i "$LOCAL_GENESIS_PATH"
        globSet GENESIS_SHA256 "$(sha256 $LOCAL_GENESIS_PATH)"
        echoInfo "INFO: Success, genesis file was copied to $LOCAL_GENESIS_PATH"
    fi

    echoInfo "INFO: Awaiting node status..."
    STATUS=$(timeout 6 curl 0.0.0.0:$(globGet CUSTOM_RPC_PORT)/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") 
    NODE_ID=$(echo "$STATUS" | jsonQuickParse "id" || echo -n "")
    if (! $(isNodeId "$NODE_ID")); then
        echoWarn "WARNING: Status and Node ID is not available, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 12 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME node id found: $NODE_ID" ; fi

    echoInfo "INFO: Awaiting first blocks to be synced or produced..."
    HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" || echo -n "")

    if (! $(isNaturalNumber "$HEIGHT")) ; then
        echoWarn "INFO: New blocks are not beeing synced or produced yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        sleep 10 && continue
    else echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing or producing new blocks" && break ; fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_COMMON/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 200 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

[ ! -f "$LOCAL_GENESIS_PATH" ] && \
    echoErr "ERROR: Failed to copy genesis file from the $CONTAINER_NAME node" && exit 1

[ "$NODE_ID" != "$EXPECTED_NODE_ID" ] && \
    echoErr "ERROR: Container $CONTAINER_NAME Node Id check failed! Expected '$EXPECTED_NODE_ID', but got '$NODE_ID'" && exit 1

[ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] && \
    echoErr "ERROR: $CONTAINER_NAME did NOT acheive running status" && exit 1

if [ "$(globGet NEW_NETWORK)" == "true" ] ; then
    echoInfo "INFO: New network was launched, attempting to setup essential post-genesis proposals..."

    declare -a perms=(
        "PermWhitelistAccountPermissionProposal" 
        "PermRemoveWhitelistedAccountPermissionProposal" 
        "PermCreateUpsertTokenAliasProposal"
        "PermCreateSoftwareUpgradeProposal"
        "PermVoteWhitelistAccountPermissionProposal"
        "PermVoteRemoveWhitelistedAccountPermissionProposal"
        "PermVoteUpsertTokenAliasProposal"
        "PermVoteSoftwareUpgradeProposal")

    for p in "${perms[@]}" ; do
        echoInfo "INFO: Whitelisting permission '$p'..."
        docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$$p validator 180"
        PERM_CHECK=$(docker exec -i validator bash -c "source /etc/profile && isPermWhitelisted validator \$$p")
        [ "${PERM_CHECK,,}" != "true" ] && echoErr "ERROR: Failed to whitelist '$p'" && exit 1
    done

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e

    echoInfo "INFO: Updating identity registrar..."
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"description\" \"This is genesis validator account of the KIRA Team\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"social\" \"https://tg.kira.network,twitter.kira.network\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"contact\" \"https://support.kira.network\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"website\" \"https://kira.network\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"username\" \"KIRA\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"logo\" \"https://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"avatar\" \"https://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"pentest1\" \"<iframe src=javascript:alert(1)>\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"pentest2\" \"<img/src=x a='' onerror=alert(2)>\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"pentest3\" \"<img src=1 onerror=alert(3)>\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"validator_node_id\" \"$EXPECTED_NODE_ID\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord test \"username\" \"test\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord signer \"username\" \"faucet\" 180"

    echoInfo "INFO: Creating initial upsert token aliases proposals and voting on them..."
    set -x

    KEX_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="KEX" \
 --name="KIRA" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg" \
 --decimals=6 \
 --denoms="ukex" \
 --title="Upsert KEX icon URL link" \
 --description="Initial Setup From KIRA Manager" \
 --chain-id=\$NETWORK_NAME --home=\$SEKAID_HOME  --fees=100ukex --yes --broadcast-mode=async --output=json | txAwait 180
EOL
)

    TEST_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="TEST" \
 --name="Test TestCoin" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/test.svg" \
 --decimals=8 \
 --denoms="test" \
 --title="Upsert Test TestCoin icon URL link" \
 --description="Initial Setup From KIRA Manager" \
 --chain-id=\$NETWORK_NAME --home=\$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async --output=json | txAwait 180
EOL
)

    SAMOLEAN_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="SAMO" \
 --name="Samolean TestCoin" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/samolean.svg" \
 --decimals=18 \
 --denoms="samolean" \
 --title="Upsert Samolean TestCoin icon URL link" \
 --description="Initial Setup From KIRA Manager" \
 --chain-id=\$NETWORK_NAME --home=\$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async --output=json  | txAwait 180
EOL
)

# NOTE: Only initial plan should be called genesis, plans with such name will NOT be executed!
    UPGRADE_RESOURCES="{\"id\":\"kira\",\"url\":\"$(globGet INFRA_SRC)\"}"
    UPGRADE_TIME=$(($(date -d "$(date)" +"%s") + 900))
    UPGRADE_PROPOSAL=$(cat <<EOL
sekaid tx upgrade proposal-set-plan --from=validator --keyring-backend=test \
 --name="genesis" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources='[$UPGRADE_RESOURCES]' \
 --min-upgrade-time=$UPGRADE_TIME \
 --old-chain-id="\$NETWORK_NAME" \
 --new-chain-id="\$NETWORK_NAME" \
 --rollback-memo="genesis" \
 --max-enrollment-duration=666 \
 --upgrade-memo="Genesis Setup Plan" \
 --chain-id=\$NETWORK_NAME --home=\$SEKAID_HOME --fees=100ukex --log_format=json --yes --output=json  | txAwait 180
EOL
)

    VOTE_YES_LAST_PROPOSAL="voteYes \$(lastProposal) validator"
    QUERY_LAST_PROPOSAL="showProposal \$(lastProposal)"
    PREVIOUS_PROPOSAL="0"

    set -x
    set -e

    docker exec -i validator bash -c "source /etc/profile && $KEX_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq

    LAST_PROPOSAL=$(docker exec -i validator bash -c "source /etc/profile && lastProposal" || "0") 
    (! $(isNaturalNumber $LAST_PROPOSAL)) && LAST_PROPOSAL=0
    [ "$LAST_PROPOSAL" == "$PREVIOUS_PROPOSAL" ] && echoErr "ERROR: New proposal was not created!" && exit 1
    PREVIOUS_PROPOSAL=$LAST_PROPOSAL && echoWarn "[$LAST_PROPOSAL] Time now: $(date '+%Y-%m-%dT%H:%M:%S')"
    
    docker exec -i validator bash -c "source /etc/profile && $TEST_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq

    LAST_PROPOSAL=$(docker exec -i validator bash -c "source /etc/profile && lastProposal" || "0") 
    (! $(isNaturalNumber $LAST_PROPOSAL)) && LAST_PROPOSAL=0
    [ "$LAST_PROPOSAL" == "$PREVIOUS_PROPOSAL" ] && echoErr "ERROR: New proposal was not created!" && exit 1
    PREVIOUS_PROPOSAL=$LAST_PROPOSAL && echoWarn "[$LAST_PROPOSAL] Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    docker exec -i validator bash -c "source /etc/profile && $SAMOLEAN_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    
    LAST_PROPOSAL=$(docker exec -i validator bash -c "source /etc/profile && lastProposal" || "0") 
    (! $(isNaturalNumber $LAST_PROPOSAL)) && LAST_PROPOSAL=0
    [ "$LAST_PROPOSAL" == "$PREVIOUS_PROPOSAL" ] && echoErr "ERROR: New proposal was not created!" && exit 1
    PREVIOUS_PROPOSAL=$LAST_PROPOSAL && echoWarn "[$LAST_PROPOSAL] Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    docker exec -i validator bash -c "source /etc/profile && $UPGRADE_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    
    LAST_PROPOSAL=$(docker exec -i validator bash -c "source /etc/profile && lastProposal" || "0") 
    (! $(isNaturalNumber $LAST_PROPOSAL)) && LAST_PROPOSAL=0
    [ "$LAST_PROPOSAL" == "$PREVIOUS_PROPOSAL" ] && echoErr "ERROR: New proposal was not created!" && exit 1
    PREVIOUS_PROPOSAL=$LAST_PROPOSAL && echoWarn "[$LAST_PROPOSAL] Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

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