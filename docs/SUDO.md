
## Set Execution Fee

```
whitelistPermission validator $PermChangeTxFee $(showAddress validator)

setExecutionFee validator pause 100 200 60

# Query Execution Fee change
showExecutionFee pause
```