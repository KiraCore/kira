
# Faucet

Default `faucet` account is by available on the first deployed validator, address and can be found by typing `echo $FAUCET_ADDR` from within the container

Faucet address is a kira account, e.g.: `kira1arn6lr665jfrjm6k7zxx5y2a0m5fcjj3lkem6e`

INTER also provides faucet address which can be found by sending following request from the host:

```
echo $(curl 0.0.0.0:$KIRA_INTERX_PORT/api/faucet | jq -rc '.address')
```


## Quick Faucet Fuel

```
read -p "INPUT ADDRESS: " ADDR && sekaid tx bank send validator $ADDR "100000000ukex" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq && sekaid tx bank send validator $ADDR "10000000000test" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq && sekaid tx bank send validator $ADDR "100000000000000000000samolean" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq
```
