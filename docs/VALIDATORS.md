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
whitelistValidators validator kira1zlry4hl2sl636xkhhza4emny3dsl68lh8zk8l0 && \
whitelistValidators validator ??? && \
whitelistValidators validator ??? 
```

## DEMO Keys and corresponding master mnemonics

```
# extract master mnemonic from secrets dir
tryGetVar MASTER_MNEMONIC "/home/ubuntu/.secrets/mnemonics.env"

# extract validator addr menmonic
tryGetVar VALIDATOR_ADDR_MNEMONIC "/home/ubuntu/.secrets/mnemonics.env"

# genesis validator: kira1zjqvrcg83m7awxpwgcjusn5j4x2fmxhm59ujxx
# > master: nose survey across coin naive slender ecology coil session bar visit ancient mail space scatter valve mask coyote blue pencil utility cross lucky pledge
# >   addr: roof wine blush attend aware kit round shoulder pelican figure maze cool ugly danger artwork main mandate desert produce impact deny silk miracle tourist

# kira1zlry4hl2sl636xkhhza4emny3dsl68lh8zk8l0
# > master: boil thing column ramp under blast gate like struggle magnet believe planet write decline chronic faculty gallery nothing gown chase silent nose edit snake
# >   addr: cable require discover gravity wrap faculty anger apology forest onion possible fiscal measure actress eager budget captain coil powder lion laundry arrive brain feed

# ???
# > master: 
# >   addr: 

# > master: 
# >   addr: 
```