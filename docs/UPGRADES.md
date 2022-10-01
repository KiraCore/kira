
# Setting Up Permissions

> Propose & Vote on Upgrade Proposals

```
whitelistPermission validator $PermCreateSoftwareUpgradeProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal $(showAddress validator) && \
whitelistValidators validator kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 && \
whitelistValidators validator kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c && \
whitelistValidators validator kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads 180
```

> Creating Soft Fork Update Plan

```
HASH="bafybeidrg5tjsh7ucsguxd2fuajv6rz42dirpwbqmloqbgxqxdaooy3p5m" && \
RES1="{\"id\":\"kira\",\"git\":\"https://ipfs.kira.network/ipfs/$HASH/kira.zip\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="Soft Fork - Test Upgrade - $(date)" \
 --instate-upgrade=true \
 --skip-handler=true \
 --resources="[${RES1}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade with no changes in sekaid binary" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes --output=json | txAwait 180

voteYes $(lastProposal) validator
voteNo $(lastProposal) validator


showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan (same binary)

```
HASH="bafybeidrg5tjsh7ucsguxd2fuajv6rz42dirpwbqmloqbgxqxdaooy3p5m" && \
RES1="{\"id\":\"kira\",\"git\":\"https://ipfs.kira.network/ipfs/$HASH/kira.zip\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="Hard Fork - Test Upgrade - $(date)" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${RES1}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$(echo $NETWORK_NAME | cut -d '-' -f 1)-$(($(echo $NETWORK_NAME | cut -d '-' -f 2) + 1))" \
 --rollback-memo="roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade with no changes in sekaid binary" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes --output=json | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan (different binary)

```
HASH="bafybeifqhdxfpt2vmgjpbnkov43afh5yvaye2r3udx2hk3gdpic326suoi" && \
RES1="{\"id\":\"kira\",\"git\":\"https://ipfs.kira.network/ipfs/$HASH/kira.zip\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="Hard Fork - Test Upgrade - $(date)" \
 --instate-upgrade=false \
 --skip-handler=false \
 --resources="[${RES1}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$(echo $NETWORK_NAME | cut -d '-' -f 1)-$(($(echo $NETWORK_NAME | cut -d '-' -f 2) + 1))" \
 --rollback-memo="roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade with no changes in sekaid binary" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes --output=json | txAwait 180

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