
# Permissions

## Query Permissions

```
(read -p "INPUT ADDRESS: " ADDR) && showPermissions $ADDR
```


## Claim Permissions as Sudo to add new Validators

```
sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermCreateSetPermissionsProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq

sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermVoteSetPermissionProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

## Claim Permissions as Sudo to Change Token Alias

```
sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermCreateUpsertTokenAliasProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq

sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermVoteUpsertTokenAliasProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

## Claim Permissions as Sudo To Upsert Roles
```
sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermUpsertRole --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes --output=json | txAwait 180

sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermCreateRoleProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes --output=json | txAwait 180

sekaid tx customgov permission whitelist-permission --from validator --keyring-backend=test --permission=$PermVoteCreateRoleProposal --addr=$VALIDATOR_ADDR --chain-id=$NETWORK_NAME --fees=100ukex --yes --output=json  | txAwait 180

```

# Proposals

## Create Proposal to Add new Validator
```
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && sekaid tx customgov proposal assign-permission $PermClaimValidator --addr=$ADDR --from=validator --keyring-backend=test --chain-id=$NETWORK_NAME --fees=100ukex --description="Genesis Validator Adding Initial Set" --title="Add New Validator" --yes | jq
```

## Change Token Alias
```
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="KEX" \
 --name="KIRA" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg" \
 --decimals=6 \
 --denoms="ukex" \
 --title="This is an initial alias update" \
 --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

sekaid query tokens all-aliases --chain-id=$NETWORK_NAME

## Vote Yes on the Latest Proposal

```
voteYes $(lastProposal) validator
```

## Wait For Last Proposal Result

```
LAST_PROPOSAL=$(lastProposal) && sekaid query customgov votes $LAST_PROPOSAL --output json | jq && sekaid query customgov proposal $LAST_PROPOSAL --output json | jq && echo "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"
```

## Change Proposals Speed
```
sekaid tx customgov proposal set-network-property PROPOSAL_END_TIME 15 --title="Proposal End Time set to 15 seconds" --description="testing commands" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait && voteYes $(lastProposal) validator

sekaid tx customgov proposal set-network-property PROPOSAL_ENACTMENT_TIME 16 --title="Proposal Enactment Time set to 16 seconds" --description="testing commands" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait && voteYes $(lastProposal) validator
```

## Change Network Property

```
sekaid tx customgov proposal set-network-property MISCHANCE_CONFIDENCE 100 --title="100 Blocks Confidence" --description="testing commands" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait

voteYes $(lastProposal) validator

sekaid tx customgov proposal set-network-property MAX_MISCHANCE 200 --title="200 Blocks Mischance" --description="testing commands" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait 

voteYes $(lastProposal) validator

networkProperties | jq
```

## Change Data Registrar

```
whitelistPermission validator $PermCreateUpsertDataRegistryProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteUpsertDataRegistryProposal $(showAddress validator) 

upsertDataRegistry validator "code_of_conduct" "https://raw.githubusercontent.com/KiraCore/sekai/master/env.sh" "text"

voteYes $(lastProposal) validator

# To Query all Data Registry Keys
sekaid query customgov all-data-reference-keys --page-key 100000 --output=json | jq
```