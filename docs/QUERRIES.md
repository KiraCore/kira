## Show Token Aliases

```
sekaid query tokens all-aliases --output=json | jq
```

## Show Network Props

```
sekaid query customgov network-properties --output=json | jq
```

## Show List Of Validator

```
echo $(curl 0.0.0.0:11000/api/valopers?all=true | jq)
```

# List All Validator Addresses

```
curl -s https://testnet-rpc.kira.network/api/valopers?all=true | jq | grep -o '".*"' | sed 's/"//g' | grep -o '\bkira1\w*' | uniq > ./valist

# whitelistBulkPermission validator ./valist $PermVoteSoftwareUpgradeProposal
function whitelistBulkPermission() {
    local ACCOUNT=$1
    local ADDRESSES=$2
    local PERMISSION=$3
    local TIMEOUT=$4
    (! $(isNaturalNumber $TIMEOUT)) && TIMEOUT=180
    if [ -f "$ADDRESSES" ] ; then 
        echoInfo "INFO: List of addresses was found ($ADDRESSES)"
        while read address ; do
            address=$(echo "$address" | xargs || echo -n "")
            if ($(isNullOrEmpty "$address")) ; then
                echoWarn "INFO: Invalid address $address"
                continue
            fi
            echoInfo "INFO: Whitelisting '$PERMISSION' permission for address '$address'"
            whitelistPermission $ACCOUNT $PERMISSION $address $TIMEOUT || echoErr "ERROR: Failed to whitelist $PERMISSION for $address using account $ACCOUNT within ${TIMEOUT}s"
        done < $ADDRESSES
    else
        echoErr "ERROR: List of addresses was NOT found ($ADDRESSES)"
    fi
}

# setNetworkProperty validator "proposal_end_time" "259200"

# count voters 
curl -s https://testnet-rpc.kira.network/api/kira/gov/votes/668 | jq | grep -o '".*"' | sed 's/"//g' | grep -o '\bkira1\w*' | sed -n '='
curl -s https://testnet-rpc.kira.network/api/kira/gov/votes/668 | jq | grep -o '".*"' | sed 's/"//g' | grep -o '\bkira1\w*' | uniq -u | awk 'END { print NR }'

```

# List All Jailed Validator Addresses

```
curl -s https://testnet-rpc.kira.network/api/valopers?all=true | jq '.validators | .[] | select(.status=="JAILED")'  | grep -o '".*"' | sed 's/"//g' | grep -o '\bkira1\w*' | uniq > ./jailed
```

