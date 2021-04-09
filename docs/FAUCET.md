
# Faucet

Default `faucet` account is by available on the first deployed validator, address and can be found by typing `echo $FAUCET_ADDR` from within the container

Faucet address is a kira account, e.g.: `kira1arn6lr665jfrjm6k7zxx5y2a0m5fcjj3lkem6e`

INTER also provides faucet address which can be found by sending following request from the host:

```
echo $(curl 0.0.0.0:$KIRA_INTERX_PORT/api/faucet | jq -rc '.address')
```


## Quick Faucet Fuel

```
account="faucet" && read -p "INPUT ADDRESS: " ADDR && sekaid tx bank send $account $ADDR "100000000ukex" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq && sleep 10 && sekaid tx bank send $account $ADDR "10000000000test" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq && sleep 10 && sekaid tx bank send $account $ADDR "100000000000000000000samolean" --keyring-backend=test --chain-id=$NETWORK_NAME --fees 100ukex --yes | jq
```



kira1gfs2d5hynuqvspn54dpff85q3ev25uhfxqzrns
kira19pk4t7axzj8q4su05nzsrar42yc988p9rqvhu5
kira1plv9zmw5fpz0p4epz0phvrmn2vgzrx03rf8msv
kira1mvym7sfhgwnfj3k93x265x8zdylle42kc9je4c