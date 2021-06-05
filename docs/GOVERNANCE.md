
# Permissions

## Query Permissions

```
( read -p "INPUT ADDRESS: " ADDR || ADDR=$VALIDATOR_ADDR ) && sekaid query customgov permissions $VALIDATOR_ADDR
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

# Proposals

## Create Proposal to Add new Validator
```
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && sekaid tx customgov proposal assign-permission $PermClaimValidator --addr=$ADDR --from=validator --keyring-backend=test --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

## Change Token Alias
```
sekaid tx tokens proposal-upsert-alias --from validator --keyring-backend=test \
 --symbol="KEX" \
 --name="KIRA" \
 --icon="http://kira-network.s3-eu-west-1.amazonaws.com/assets/img/tokens/kex.svg" \
 --decimals=6 \
 --denoms="ukex" \
 --description="This is an initial alias update" \
 --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

sekaid query tokens all-aliases --chain-id=$NETWORK_NAME

## Vote Yes on the Latest Proposal

```
LAST_PROPOSAL=$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && sekaid tx customgov proposal vote $LAST_PROPOSAL 1 --from=validator --chain-id=$NETWORK_NAME --keyring-backend=test  --fees=100ukex --yes | jq
```

## Wait For Last Proposal Result

```
LAST_PROPOSAL=$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && sekaid query customgov votes $LAST_PROPOSAL --output json | jq && sekaid query customgov proposal $LAST_PROPOSAL --output json | jq && echo "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"
```

## Quick & Dirty Setup For Adding new Validator To The Testnet

```
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && \
sekaid tx bank send validator $ADDR "99000ukex" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes --log_format=json --gas=1000000 --broadcast-mode=async | txAwait && \
sekaid tx customgov proposal assign-permission $PermClaimValidator --addr=$ADDR --from=validator --keyring-backend=test --chain-id=$NETWORK_NAME --description="Adding Testnet Validator $ADDR" --fees=100ukex --yes --log_format=json --gas=1000000 --broadcast-mode=async | txAwait && \
LAST_PROPOSAL=$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && sekaid tx customgov proposal vote $LAST_PROPOSAL 1 --from=validator --chain-id=$NETWORK_NAME --keyring-backend=test  --fees=100ukex --yes --log_format=json --gas=1000000 --broadcast-mode=async | txAwait && \
sekaid query customgov votes $LAST_PROPOSAL --output json | jq && sekaid query customgov proposal $LAST_PROPOSAL --output json | jq && echo "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"
```

## Macro for Adding Validators
```
kira1yswhg6caeedep2xg88a795rkx9y08yucmpn2e2

read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && whitelistValidator validator $ADDR
```


sekaid tx customgov proposal set-network-property PROPOSAL_ENACTMENT_TIME 30 --description="Proposal End Time set to 1 min" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes &

## Change Proposals Speed
```
sekaid tx customgov proposal set-network-property PROPOSAL_END_TIME 15 --description="Proposal End Time set to 15 seconds" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait && voteYes $(lastProposal) validator

sekaid tx customgov proposal set-network-property PROPOSAL_ENACTMENT_TIME 16 --description="Proposal Enactment Time set to 16 seconds" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait && voteYes $(lastProposal) validator
```

## Change Network Property

```
sekaid tx customgov proposal set-network-property MISCHANCE_CONFIDENCE 100 --description="100 Blocks Confidence" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait

voteYes $(lastProposal) validator

sekaid tx customgov proposal set-network-property MAX_MISCHANCE 200 --description="200 Blocks Mischance" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async | txAwait 

voteYes $(lastProposal) validator

networkProperties | jq
```
