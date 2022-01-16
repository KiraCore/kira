
# Faucet

Default `signer` account is by available on the first deployed validator, address and can be found by typing `echo $SIGNER_ADDR` from within the container

Signer address is a kira account, e.g.: `kira1arn6lr665jfrjm6k7zxx5y2a0m5fcjj3lkem6e`

INTER also provides faucet address which can be found by sending following request from the host:

```
echo $(curl 0.0.0.0:$KIRA_INTERX_PORT/api/faucet | jq -rc '.address')
```