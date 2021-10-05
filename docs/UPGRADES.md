
# Setting Up Permissions

> Propose & Vote on Upgrade Proposals

```
whitelistPermission validator $PermCreateSoftwareUpgradeProposal $(showAddress validator)
whitelistPermission validator $PermVoteSoftwareUpgradeProposal $(showAddress validator) 
```

> Creating Soft Fork Update Plan

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-78" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-78" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="newnet-2" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```
> Latest Public testnet Soft Fork

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-78" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
 ```

> Latest Public testnet Hard Fork

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
FRONT_RES_TMP="{\"id\":\"frontend\",\"git\":\"https://github.com/KiraCore/kira-frontend\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-78" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP},${FRONT_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a planned hard fork of the public testnet" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
 ```