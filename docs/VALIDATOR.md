# Query Validator Info

```
sekaid query validator --addr=$VALIDATOR_ADDR --output=json | jq
sekaid query customslashing signing-infos $(sekaid valcons-address $VALIDATOR_ADDR) --output=json | jq
```


# Joining validator with INACTIVE status

```
sekaid tx customslashing activate --from validator --keyring-backend=test --home=$SEKAID_HOME --chain-id=$NETWORK_NAME --fees=1000ukex --yes
```


