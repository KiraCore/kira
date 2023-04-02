# Launch Validator Node

```
# using CID
HASH="bafybeifctpv7qxafkccjlsm4taqohk6ywk4ig5jxfboxwnwasopiemb2lm" && \
 cd /tmp && wget https://ipfs.kira.network/ipfs/$HASH/init.sh -O ./i.sh && \
 chmod +x -v ./i.sh && ./i.sh --infra-src="$HASH" --init-mode="interactive"
```

# Query Validator Info

```
sekaid query customstaking validator --addr=$VALIDATOR_ADDR --output=json | jq
sekaid query customslashing signing-infos $(sekaid valcons-address $VALIDATOR_ADDR) --output=json | jq
```

# Claim Validator Seat (WAITING status)

```
sekaid tx customstaking claim-validator-seat --from validator --keyring-backend=test --home=$SEKAID_HOME --moniker="NODE-B" --chain-id=$NETWORK_NAME --gas=1000000 --broadcast-mode=async --fees=100ukex --yes | txAwait
```

# Re-Joining Validator set (INACTIVE status)

```

sekaid tx customslashing activate --from validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=1000ukex --gas=1000000 --broadcast-mode=async --yes --broadcast-mode=async | txAwait
```

# Pause / Un-Pause Validator

```
sekaid tx customslashing unpause --from validator --chain-id="$NETWORK_NAME" --keyring-backend=test --home=$SEKAID_HOME --fees 100ukex --gas=1000000 --broadcast-mode=async --yes | txAwait
sekaid tx customslashing inactivate --from validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=1000ukex --gas=1000000 --broadcast-mode=async --yes | txAwait
```

## Adding Validators On Testnet
```
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && whitelistValidators validator $ADDR

e.g:

whitelistValidators validator kira1vjfq0hrmyuyxw2es4t5dm8ra5jzw9pmrkp4syh && \
whitelistValidators validator kira1pxld6ksvtnqqlqzth8kg2hv2r72e3e3huyn55t && \
whitelistValidators validator kira12spkm5dt0ptgwmk4s32kx36r46vjpy2ltfr390 
```

## DEMO Keys and corresponding mnemonics

```
# extract master mnemonic from secrets dir
tryGetVar MASTER_MNEMONIC "/home/ubuntu/.secrets/mnemonics.env"

# kira1vjfq0hrmyuyxw2es4t5dm8ra5jzw9pmrkp4syh
# awake absurd guard venture enrich balance puppy immense eternal maze cigar lock prison disease cousin true mind element weather virtual merge clog fire scrub

# kira1pxld6ksvtnqqlqzth8kg2hv2r72e3e3huyn55t
# blur hundred one tent net pledge valley finish toe jewel rice vacuum ready pizza door engage horror barely account foot make syrup thought few

# kira12spkm5dt0ptgwmk4s32kx36r46vjpy2ltfr390
# glory salute raccoon alpha cycle stuff brown two check rare wheat educate ridge dumb magic usage forum wrist raccoon erase onion cross parrot smile
```