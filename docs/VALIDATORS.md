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
read -p "INPUT ADDRESS OF YOUR NEW VALIDATOR: " ADDR && whitelistValidators validator $ADDR

e.g:

whitelistValidators validator kiraXXX && \
whitelistValidators validator kira1rccqtpytu2mkrqqchsqhz09cqlf4xmr80v7u5q && \
whitelistValidators validator kira17ueeuth594mu9pddvudng47tnqwdlwjt82ak5u
```

## Importing DEMO Keys to Test Instances

```
# kiraXXX

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "MASTER_MNEMONIC=\"XXX\"" > $KIRA_SECRETS/mnemonics.env

# kira1rccqtpytu2mkrqqchsqhz09cqlf4xmr80v7u5q

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "MASTER_MNEMONIC=\"add pill clerk smooth oxygen intact lesson rocket pilot ritual draft desert word blossom easily fuel cushion expose thunder lonely more best behind file\"" > $KIRA_SECRETS/mnemonics.env

# kira17ueeuth594mu9pddvudng47tnqwdlwjt82ak5u

KIRA_SECRETS=/home/ubuntu/.secrets && mkdir -p $KIRA_SECRETS && echo "MASTER_MNEMONIC=\"ozone toss coil raven ring include boring shrimp subway sustain appear prosper patient total burger enlist breeze chuckle salad cannon thunder recall abandon thumb\"" > $KIRA_SECRETS/mnemonics.env
```