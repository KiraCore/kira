
# Token Transfers

> KEX Transfer

```
read -p "INPUT ADDRESS: " ADDR && read -p "INPUT AMOUNT (ukex): " AMT && sekaid tx bank send faucet $ADDR "${AMT}ukex" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq
```

