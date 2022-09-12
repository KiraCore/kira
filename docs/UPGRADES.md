
# Setting Up Permissions

> Propose & Vote on Upgrade Proposals

```
whitelistPermission validator $PermCreateSoftwareUpgradeProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal $(showAddress validator) 


whitelistValidators validator kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 && \
whitelistValidators validator kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c && \
whitelistValidators validator kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c 180 && \
whitelistPermission validator $PermVoteSoftwareUpgradeProposal kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads 180
```

> Creating Soft Fork Update Plan

```
HASH="bafybeic2prkuzffxtmfkkwuhpedegsxwge2p2mn4fmkvxo7xfqz7ysdaai" && \
BASE_IMAGE_SRC="ghcr.io/kiracore/docker/kira-base:v0.11.4" && \
RES1="{\"id\":\"kira\",\"git\":\"https://ipfs.kira.network/ipfs/$HASH/kira.zip\"}" && \
RES2="{\"id\":\"kira-base\",\"git\":\"$BASE_IMAGE_SRC\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="Soft Fork - Test Upgrade - $(date)" \
 --instate-upgrade=true \
 --skip-handler=false \
 --resources="[${RES1},${RES2}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$NETWORK_NAME" \
 --rollback-memo="roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a soft fork test upgrade" \
 --from=validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_format=json --yes --output=json | txAwait 180

voteYes $(lastProposal) validator

showCurrentPlan | jq
showNextPlan | jq
```

> Creating Hard Fork Update Plan

```
HASH="bafybeifiixdxq4cli6qxib5zfiky7rilb6k66f336nymj4jty6tdsiixre" && \
BASE_IMAGE_SRC="ghcr.io/kiracore/docker/kira-base:v0.12.0" && \
RES1="{\"id\":\"kira\",\"git\":\"https://ipfs.kira.network/ipfs/$HASH/kira.zip\"}" && \
RES2="{\"id\":\"kira-base\",\"git\":\"$BASE_IMAGE_SRC\"}" && \
sekaid tx upgrade proposal-set-plan \
 --name="Hard Fork - Test Upgrade - $(date)" \
 --instate-upgrade=false \
 --skip-handler=true \
 --resources="[${RES1},${RES2}]" \
 --min-upgrade-time=$(($(date -d "$(date)" +"%s") + 900)) \
 --old-chain-id="$NETWORK_NAME" \
 --new-chain-id="$(echo $NETWORK_NAME | cut -d '-' -f 1)-$(($(echo $NETWORK_NAME | cut -d '-' -f 2) + 1))" \
 --rollback-memo="roll" \
 --max-enrollment-duration=60 \
 --upgrade-memo="This is a hard fork test upgrade" \
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