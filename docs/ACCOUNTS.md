
# Token Transfers

> KEX Transfer

```
read -p "INPUT ADDRESS: " ADDR && read -p "INPUT AMOUNT: " AMT && sekaid tx bank send test $ADDR "${AMT}" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq
```

> Faucet Accounts
```
kira1ytnqwv8dwu2ejphzfpdnewv5ehjfvs04a7205x
kira1munw5tl85u83du0zdtzm29n0ql0p4dsst8jylq
```

sendTokens validator kira1ytnqwv8dwu2ejphzfpdnewv5ehjfvs04a7205x 500000000000 ukex
sendTokens validator kira1munw5tl85u83du0zdtzm29n0ql0p4dsst8jylq 500000000000 ukex

sendTokens validator kira1ytnqwv8dwu2ejphzfpdnewv5ehjfvs04a7205x 1 ukex