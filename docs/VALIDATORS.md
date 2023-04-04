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
whitelistValidators validator kira1vumk6952urr5ee7v79q072v5ztr94k4z7a2fv2 && \
 whitelistValidators validator kira19pdg83nju0acrk3jcw9gxhmvu257puc9t2334h && \
 whitelistValidators validator kira1nxtp8ly7x7fwnu2l737ckslk2u7y3mfv9fu938 
```

## DEMO Keys and corresponding master mnemonics

```
# extract master mnemonic from secrets dir
tryGetVar MASTER_MNEMONIC "/home/ubuntu/.secrets/mnemonics.env"

# extract validator addr menmonic
tryGetVar VALIDATOR_ADDR_MNEMONIC "/home/ubuntu/.secrets/mnemonics.env"

# genesis validator: kira19m4r9zrk4jwj0vht4rxjcapsqhah5t7p6swrcm
# > master: lava sun bread face village voice sing humble milk junior cupboard address cool earn snow monkey turtle bacon depth citizen trash idea amazing goat
# >   addr: fetch autumn physical winner walnut fee spoil alley critic interest stamp save roast smoke seminar feature weather issue fix session deliver hamster fence spirit

# devnet 2 validator: kira1vumk6952urr5ee7v79q072v5ztr94k4z7a2fv2
# > master: life file diagram congress talent team sting topic crack potato sister topic speak gain rural estate chaos shop aisle eagle never crystal exhaust note
# >   addr: chapter dutch brand marriage soft jaguar group humor dirt knock grunt own lonely panic nest regular pave wire track amused language dance vapor leaf

# devnet 3 validator: kira19pdg83nju0acrk3jcw9gxhmvu257puc9t2334h
# > master: brief apple famous just liquid gadget text noise blue camera match ramp laptop chaos borrow flip mirror position solar inherit desert dose blanket mimic
# >   addr: indicate marine rookie fabric problem parent rally ozone leopard practice permit pen fever clock museum renew unit bicycle addict light consider ask mad object

# devnet 4 validator: kira1nxtp8ly7x7fwnu2l737ckslk2u7y3mfv9fu938
# > master: easily cave will detail cake pyramid weekend street intact pill number asthma purpose wreck strong attack survey broom sorry child capital sport knife pause
# >   addr: elbow scrap parrot liberty suspect wedding end fine various situate fiber kangaroo vote jazz census hen bread day sorry one mean episode umbrella animal
```