
# Token Transfers

> KEX Transfer

```
read -p "INPUT ADDRESS: " ADDR && read -p "INPUT AMOUNT: " AMT && sekaid tx bank send test $ADDR "${AMT}" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq
```
