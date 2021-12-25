
# Setting Up Permissions

> Propose & Vote on Upgrade Proposals

```
whitelistPermission validator $PermCreateSoftwareUpgradeProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal $(showAddress validator) 


whitelistValidator validator kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 && \
whitelistValidator validator kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c && \
whitelistValidator validator kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads 180
```

> Creating Soft Fork Update Plan

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-94" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes --output=json | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan

```
UPGRADE_NAME_TMP="upgrade-115" && UPGRADE_TIME=$(($(date -d "$(date)" +"%s") + 800)) && \
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"master\",\"checksum\":\"\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP}]" \
 --min-upgrade-time="$UPGRADE_TIME" \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="devnet-20" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --output=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```
> Latest Public testnet Soft Fork

```
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"testnet-5\",\"checksum\":\"\"}" && \
UPGRADE_NAME_TMP="upgrade-94" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a public testnet, planned soft fork upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
 ```

> Latest Public testnet Hard Fork (2010-10-23 10:30 PM)

```
UPGRADE_NAME_TMP="upgrade-94" && UPGRADE_BRANCH="testnet-8" && UPGRADE_TIME=$(date2unix "2021-11-06T16:30:00Z") && \
INFRA_RES_TMP="{\"id\":\"kira\",\"git\":\"https://github.com/KiraCore/kira\",\"checkout\":\"$UPGRADE_BRANCH\",\"checksum\":\"\"}" && \
SEKAI_RES_TMP="{\"id\":\"sekai\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"$UPGRADE_BRANCH\",\"checksum\":\"\"}" && \
INTRX_RES_TMP="{\"id\":\"interx\",\"git\":\"https://github.com/KiraCore/sekai\",\"checkout\":\"$UPGRADE_BRANCH\",\"checksum\":\"\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="$UPGRADE_NAME_TMP" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${INFRA_RES_TMP},${SEKAI_RES_TMP},${INTRX_RES_TMP}]" \
 --min-upgrade-time="$UPGRADE_TIME" \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$UPGRADE_BRANCH" \
 --rollback-memo="${UPGRADE_NAME_TMP}-roll" \
 --max-enrollment-duration=90 \
 --upgrade-memo="This is a planned hard fork of the public testnet" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
 ```

 # Halt services to simulate missing validators

 ```
systemctl stop kiraup && systemctl stop kiraplan && systemctl stop kirascan && \
 echo "INFO: Successfully stopped all services" || echo "WARNING: Failed to stop all services"
 ```

# Unhalt services to reboot missing validators

 ```
systemctl start kiraup && systemctl start kiraplan && systemctl start kirascan && \
 echo "INFO: Successfully started all services" || echo "WARNING: Failed to start all services"
 ```