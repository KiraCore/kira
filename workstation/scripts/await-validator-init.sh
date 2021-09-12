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

    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermCreateSetPermissionsProposal \$VALIDATOR_ADDR 180"
    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermCreateUpsertTokenAliasProposal \$VALIDATOR_ADDR 180"
    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermCreateSoftwareUpgradeProposal \$VALIDATOR_ADDR 180"

    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermVoteSetPermissionProposal \$VALIDATOR_ADDR 180"
    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermVoteUpsertTokenAliasProposal \$VALIDATOR_ADDR 180"
    docker exec -i validator bash -c "source /etc/profile && whitelistPermission validator \$PermVoteSoftwareUpgradeProposal \$VALIDATOR_ADDR 180"

    echoInfo "INFO: Creating initial upsert token aliases proposals and voting on them..."

    KEX_UPSERT=$(cat <<EOL
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="KEX" \
 --name="KIRA" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg" \
 --decimals=6 \
 --denoms="ukex" \
 --title="Upsert KEX icon URL link" \
 --description="Initial Setup From KIRA Manager" \
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes --broadcast-mode=async | txAwait 180
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
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes --broadcast-mode=async | txAwait 180
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
 --chain-id=\$NETWORK_NAME --fees=100ukex --yes --broadcast-mode=async | txAwait 180
EOL
)

    UPGRADE_NAME=$(cat $KIRA_INFRA/upgrade || echo "")
    [ -z "UPGRADE_NAME" ] && echoErr "ERROR: Invalid upgrade namen!" && exit 1

    UPGRADE_RESOURCES=""
    REPO_ZIP="/tmp/repo.zip"
    REPO_TMP="/tmp/repo"

    rm -fv $REPO_ZIP && cd $HOME && rm -rfv $REPO_TMP && mkdir -p $REPO_TMP
    $KIRA_SCRIPTS/git-pull.sh "$INFRA_REPO" "$INFRA_BRANCH" "$REPO_TMP" 555
    CHECKSUM=$(CDHelper hash SHA256 -p="$REPO_TMP" -x=true -r=true --silent=true -i="$REPO_TMP/.git,$REPO_TMP/.gitignore")
    UPGRADE_RESOURCES="{\"id\":\"kira\",\"git\":\"$INFRA_REPO\",\"checkout\":\"$INFRA_BRANCH\",\"checksum\":\"$CHECKSUM\"}"

    rm -fv $REPO_ZIP && cd $HOME && rm -rfv $REPO_TMP && mkdir -p $REPO_TMP
    $KIRA_SCRIPTS/git-pull.sh "$SEKAI_REPO" "$SEKAI_BRANCH" "$REPO_TMP" 555
    CHECKSUM=$(CDHelper hash SHA256 -p="$REPO_TMP" -x=true -r=true --silent=true -i="$REPO_TMP/.git,$REPO_TMP/.gitignore")
    UPGRADE_RESOURCES="${UPGRADE_RESOURCES},{\"id\":\"sekai\",\"git\":\"$SEKAI_REPO\",\"checkout\":\"$SEKAI_BRANCH\",\"checksum\":\"$CHECKSUM\"}"

    rm -fv $REPO_ZIP && cd $HOME && rm -rfv $REPO_TMP && mkdir -p $REPO_TMP
    $KIRA_SCRIPTS/git-pull.sh "$INTERX_REPO" "$INTERX_BRANCH" "$REPO_TMP" 555
    CHECKSUM=$(CDHelper hash SHA256 -p="$REPO_TMP" -x=true -r=true --silent=true -i="$REPO_TMP/.git,$REPO_TMP/.gitignore")
    UPGRADE_RESOURCES="${UPGRADE_RESOURCES},{\"id\":\"interx\",\"git\":\"$INTERX_REPO\",\"checkout\":\"$INTERX_BRANCH\",\"checksum\":\"$CHECKSUM\"}"

    rm -fv $REPO_ZIP && cd $HOME && rm -rfv $REPO_TMP && mkdir -p $REPO_TMP
    $KIRA_SCRIPTS/git-pull.sh "$FRONTEND_REPO" "$FRONTEND_BRANCH" "$REPO_TMP" 555
    CHECKSUM=$(CDHelper hash SHA256 -p="$REPO_TMP" -x=true -r=true --silent=true -i="$REPO_TMP/.git,$REPO_TMP/.gitignore")
    UPGRADE_RESOURCES="${UPGRADE_RESOURCES},{\"id\":\"frontend\",\"git\":\"$FRONTEND_REPO\",\"checkout\":\"$FRONTEND_BRANCH\",\"checksum\":\"$CHECKSUM\"}"

    UPGRADE_PROPOSAL=$(cat <<EOL
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME" \
 --instate-upgrade=true \
 --resources='[$UPGRADE_RESOURCES]' \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --height=0  \
 --old-chain-id="\$NETWORK_NAME" \
 --new-chain-id="\$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME}-roll" \
 --max-enrollment-duration=1 \
 --upgrade-memo="Genesis setup plan" \
 --from=validator --keyring-backend=test --chain-id=\$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180
EOL
)
    globSet "UPGRADE_NAME" "$UPGRADE_NAME"

    VOTE_YES_LAST_PROPOSAL="voteYes \$(lastProposal) validator"
    QUERY_LAST_PROPOSAL="showProposal \$(lastProposal)"

    docker exec -i validator bash -c "source /etc/profile && $KEX_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    docker exec -i validator bash -c "source /etc/profile && $TEST_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    docker exec -i validator bash -c "source /etc/profile && $SAMOLEAN_UPSERT"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    docker exec -i validator bash -c "source /etc/profile && $UPGRADE_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $VOTE_YES_LAST_PROPOSAL"
    docker exec -i validator bash -c "source /etc/profile && $QUERY_LAST_PROPOSAL" | jq
    echoWarn "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e

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
    #docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"validator_node_id\" \"$VALIDATOR_NODE_ID\" 180"

    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord test \"username\" \"KIRA-TEST\" 180"
    docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord faucet \"username\" \"KIRA-FAUCET\" 180"

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