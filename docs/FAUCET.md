
# Faucet

Default `faucet` account is by available on the first deployed validator, address and can be found by typing `echo $FAUCET_ADDR` from within the container

Faucet address is a kira account, e.g.: `kira1dndc9jvc90jafmmrx2c63aqryvgekr3ycm609c`

INTER also provides faucet address which can be found by sending following request from the host:

```
echo $(curl 0.0.0.0:$KIRA_INTERX_PORT/api/faucet | jq -rc '.address')
```

