
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

## Change Network Property

```
whitelistPermission validator $PermCreateSetNetworkPropertyProposal  $(showAddress validator) && \
whitelistPermission validator $PermVoteSetNetworkPropertyProposal  $(showAddress validator) 

setNetworkProperty validator "MIN_TX_FEE" "99"

voteYes $(lastProposal) validator

showNetworkProperties | jq
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

## Change Proposals Duration

```
whitelistPermission validator $PermCreateSetProposalDurationProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteSetProposalDurationProposal $(showAddress validator) 

setProposalsDurations validator "UpsertDataRegistry,SetNetworkProperty" "300,300"

voteYes $(lastProposal) validator

# To Query all Proposals Durations
showProposalsDurations
```

## Set Poor Network Messages

```
whitelistPermission validator $PermCreateSetProposalDurationProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteSetPoorNetworkMessagesProposal  $(showAddress validator) 

setPoorNetworkMessages validator "submit_evidence,submit-proposal,vote-proposal,claim-councilor,set-network-properties,claim-validator,activate,pause,unpause" 

voteYes $(lastProposal) validator

# To Poor Network Messages
showPoorNetworkMessages
```

## ReSet Ranks of All Validators

```
whitelistPermission validator $PermCreateResetWholeValidatorRankProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteResetWholeValidatorRankProposal  $(showAddress validator) 

resetRanks validator

voteYes $(lastProposal) validator
```


## Set Token Rates

```
whitelistPermission validator $PermCreateUpsertTokenRateProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteUpsertTokenRateProposal $(showAddress validator) 

setTokenRate validator lol 2 true

voteYes $(lastProposal) validator
```

## Set Token Transfers Black/White List

```
whitelistPermission validator $PermCreateTokensWhiteBlackChangeProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteTokensWhiteBlackChangeProposal $(showAddress validator) 

transfersWhitelistAddTokens validator "samolean"
transfersWhitelistRemoveTokens validator "samolean"
transfersBlacklistAddTokens validator "samolean"
transfersBlacklistRemoveTokens validator "samolean"

voteYes $(lastProposal) validator

# query whitelist/blacklist
showTokenTransferBlackWhiteList
```

## Unjailing Validator
```
whitelistPermission validator $PermCreateUnjailValidatorProposal $(showAddress validator) && \
whitelistPermission validator $PermVoteUnjailValidatorProposal $(showAddress validator)

unjail validator "kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c"

voteYes $(lastProposal) validator
```


