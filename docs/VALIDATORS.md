# Launch Validator Node

```
cd /tmp && read -p "Input branch name: " BRANCH && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$BRANCH/workstation/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && H=$(sha256sum ./i.sh | awk '{ print $1 }') && read -p "Is '$H' a [V]alid SHA256 ?: "$'\n' -n 1 V && \
 [ "${V,,}" == "v" ] && ./i.sh "$BRANCH" || echo "Hash was NOT accepted by the user"
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
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && whitelistValidator validator $ADDR

e.g:

whitelistValidator validator kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6 && \
whitelistValidator validator kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c && \
whitelistValidator validator kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads
```

## Importing DEMO Keys to Test Instances

```
# kira1ejck5umkhdylea964yjqu9phr7lkz0t4d748d6

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "VALIDATOR_ADDR_MNEMONIC=\"strong picture raccoon decide debate orange honey benefit gym spell vendor moment mule ancient liar assist naive venture ability obtain trade reject short borrow\" >> $KIRA_SECRETS/mnemonics.env && echo "VALIDATOR_VAL_MNEMONIC=\"reward weapon cake shop sorry feature tone cluster era nut leg canoe burden man soldier reform neck narrow squirrel vintage teach dial broken mimic\" >> $KIRA_SECRETS/mnemonics.env

# kira1ag6ct3jxeh7rcdhvy8g3ajdhjrs3g6470v3s7c

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "VALIDATOR_ADDR_MNEMONIC=\"waste forum motion vivid verb excite roast stuff virus embody assume hurt window album once cushion setup salon fiction custom glove also armed edge\" >> $KIRA_SECRETS/mnemonics.env && echo "VALIDATOR_VAL_MNEMONIC=\"word visit pelican venue nominee echo symptom devote cargo where guide derive creek rather poem thought own bulk token lounge tunnel unlock buffalo lecture\" >> $KIRA_SECRETS/mnemonics.env

# kira1ftp05qcmen9r8w6g7ajdxtmy0hldk39s3h0ads

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "VALIDATOR_ADDR_MNEMONIC=\"eagle please appear wide quit hat column stereo vapor buddy seed busy rude bag peanut six speak rescue click claw trade robot tragic soldier\" >> $KIRA_SECRETS/mnemonics.env && echo "VALIDATOR_VAL_MNEMONIC=\"slight peasant company hood average ivory panic diary barrel fault solar broken birth smoke over unveil fortune cloth orient kidney harsh remain glad slab\" >> $KIRA_SECRETS/mnemonics.env
```