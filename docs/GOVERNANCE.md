
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
## Adding Validators
```
kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6
kira10p4uaylvx7les2ara6unzl0tkkldt4h8xwjvzp
kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads

read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && whitelistValidator validator $ADDR
```


sekaid tx customgov proposal set-network-property PROPOSAL_ENACTMENT_TIME 30 --title="Proposal End Time set to 1 min" --description="testing commands" --from validator --keyring-backend=test --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes &

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
## Network Updates

```
sekaid tx upgrade set-plan \
 --resource-id=1 \
 --resource-git=1 \
 --resource-checkout=1 \
 --resource-checksum=1 \
 --min-halt-time=1 \
 --old-chain-id=$NETWORK_NAME \
 --new-chain-id=1 \
 --rollback-memo=1 \
 --max-enrollment-duration=1 
 --upgrade-memo=1 
 --from=validator 
 --keyring-backend=test 
 --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=100ukex --log_level=debug --yes --broadcast-mode=async | txAwait 

```

```
{
    "resources": [ {
            "id": "kira",
            "git": "<url-string>",
            "checkout": "<branch-or-tag-string>",
            "checksum": "sha256-string"
        }, {
            "id": "chain",
            "git": ...
        }, { ... }, ...
    ],
    "min_halt_time": <uint>,
    "old_chain_id": <string>,
    "new_chain_id": <string>,
    "rollback_checksum": <sha256-string>,
    "max_enrolment_duration": <uint>,
    "memo": <string>
}
```


[ {
            "id": "sekai",
            "git": "https://github.com/KiraCore/sekai",
            "checkout": "master",
            "checksum": "sha256-string"
        }, {
            "id": "interx",
            "git": "https://github.com/KiraCore/sekai",
            "checkout": "master",
            "checksum": "sha256-string"
        }
    ]