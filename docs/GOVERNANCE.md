
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
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && out="" && tx=$(sekaid tx bank send validator $ADDR "99000ukex" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes --log_format=json --broadcast-mode=async | jq -rc '.txhash') && while [ -z "$out" ] ; do echo "Waiting for tx bank send '$tx' to be included in the block..." && sleep 15 && out=$(sekaid query tx $tx --output=json 2> /dev/null | jq -rc '.' || echo -n "") ; done && echo $out | jq && \
echo -n "" && \
out="" && tx=$(sekaid tx customgov proposal assign-permission $PermClaimValidator --addr=$ADDR --from=validator --keyring-backend=test --chain-id=$NETWORK_NAME --description="Adding Testnet Validator $ADDR" --fees=100ukex --yes --log_format=json --broadcast-mode=async | jq -rc '.txhash') && while [ -z "$out" ] ; do echo "Waiting for tx customgov proposal assign-permission '$tx' to be included in the block..." && sleep 15 && out=$(sekaid query tx $tx --output=json 2> /dev/null | jq -rc '.' || echo -n "") ; done && echo $out | jq && LAST_PROPOSAL=$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && \
echo -n "" && \
out="" && tx=$(sekaid tx customgov proposal vote $LAST_PROPOSAL 1 --from=validator --chain-id=$NETWORK_NAME --keyring-backend=test  --fees=100ukex --yes --log_format=json --broadcast-mode=async | jq -rc '.txhash') && while [ -z "$out" ] ; do echo "Waiting for tx customgov proposal vote '$tx' to be included in the block..." && sleep 15 && out=$(sekaid query tx $tx --output=json 2> /dev/null | jq -rc '.' || echo -n "") ; done && echo $out | jq && sekaid query customgov votes $LAST_PROPOSAL --output json | jq && sekaid query customgov proposal $LAST_PROPOSAL --output json | jq && echo "Time now: $(date '+%Y-%m-%dT%H:%M:%S')"
```

## Change Proposals Speed

LAST_PROPOSAL=$(sekaid query customgov proposals --output json | jq -cr '.proposals | last | .proposal_id') && NEXT_PROPOSAL=$((LAST_PROPOSAL + 1)) 

sekaid tx customgov proposal set-network-property PROPOSAL_END_TIME 60 --description="Proposal End Time set to 1 min" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes &

sekaid tx customgov proposal vote $NEXT_PROPOSAL 1 --from=validator --chain-id=$NETWORK_NAME --keyring-backend=test  --fees=100ukex --yes



