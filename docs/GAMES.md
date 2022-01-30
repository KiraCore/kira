# Useful Games Commands

```

# whitelist permission to assign claimValidator permission

whitelistPermission validator $PermSetClaimValidatorPermission bob 

# Assign claimValidator permission to account

whitelistPermission bob 2 ana 

sekaid tx customgov permission whitelist --from bob --permission="2" --addr="kira18rfg8h6y8npvfxpes28fnuh0xzwd78hr2frc2d" --keyring-backend=test  --chain-id=$NETWORK_NAME --home=$SEKAID_HOME --fees=100ukex --yes --broadcast-mode=async --log_format=json --output=json 

sendTokens bob ana 1000 ukex

# PermChangeTxFee == 7
whitelistPermission validator 7 validator 

addAccount bob
sendTokens validator bob 1000 ukex 100 ukex

setExecutionFee validator "set-execution-fee" 200 200 60
showExecutionFee "set-execution-fee"

```