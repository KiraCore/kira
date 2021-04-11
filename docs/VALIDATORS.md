# Launch Validator Node

```
cd /tmp && read -p "Input branch name: " BRANCH && \
 wget https://raw.githubusercontent.com/KiraCore/kira/$BRANCH/workstation/init.sh -O ./i.sh && \
 chmod 555 -v ./i.sh && H=$(sha256sum ./i.sh | awk '{ print $1 }') && read -p "Is '$H' a [V]alid SHA256 ?: "$'\n' -n 1 V && \
 [ "${V,,}" == "v" ] && ./i.sh "$BRANCH" || echo "Hash was NOT accepted by the user"
```


# Query Validator Info

```
sekaid query validator --addr=$VALIDATOR_ADDR --output=json | jq
sekaid query customslashing signing-infos $(sekaid valcons-address $VALIDATOR_ADDR) --output=json | jq
```

# Claim Validator Seat (WAITING status)

```
sekaid tx customstaking claim-validator-seat --from validator --keyring-backend=test --home=$SEKAID_HOME --moniker="NODE-B" --chain-id=$NETWORK_NAME --fees=100ukex --yes | jq
```

# Re-Joining Validator set (INACTIVE status)

```


out="" && tx=$(sekaid tx customslashing activate --from validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=1000ukex --yes --broadcast-mode=async | jq -rc '.txhash') && \
while [ -z "$out" ] ; do echo "Waiting for '$tx' to be included in the block..." && sleep 5 && \
out=$(sekaid query tx $tx --output=json 2> /dev/null | jq -rc '.' || echo -n "") ; done && \
echo $out | jq
```


# Pause / Un-Pause Validator

```
sekaid tx customslashing unpause --from validator --chain-id="$NETWORK_NAME" --keyring-backend=test --home=$SEKAID_HOME --fees 100ukex --yes | jq
sekaid tx customslashing inactivate --from validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=1000ukex --yes | jq
```
