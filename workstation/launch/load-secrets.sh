#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
echoInfo "INFO: Loading secrets..."

MNEMONICS="$KIRA_SECRETS/mnemonics.env"
mkdir -p "$KIRA_SECRETS"
touch $MNEMONICS

function MnemonicGenerator() {
    loadGlobEnvs
    local MNEMONICS="$KIRA_SECRETS/mnemonics.env"
    source $MNEMONICS

    # master mnemonic used to derive other mnemonics
    local masterMnemonic="$MASTER_MNEMONIC"
    # expected variable name
    local mnemonicVariableName=$(toUpper "${1}_${2}_MNEMONIC")
    # Default entropy == "${masterMnemonic} ; ${mnemonicVariableName}"
    local entropyHex=$(echo -n "$masterMnemonic ; ${1} ${2}" | tr '[:upper:]' '[:lower:]' | sha256sum | awk '{ print $1 }' | xargs)

    local valkeyPath="$KIRA_SECRETS/priv_${1,,}_key.json"
    local nodekeyPath="$KIRA_SECRETS/${1,,}_node_key.json"
    local keyidPath="$KIRA_SECRETS/${1,,}_node_id.key"

    mnemonic="${!mnemonicVariableName}"
    mnemonic=$(echo "$mnemonic" | xargs || echo -n "")

    if (! $(isMnemonic "$mnemonic")) ; then # if mnemonic is not present then generate new one
        echoInfo "INFO: $mnemonicVariableName was not found, regenerating..."
        mnemonic=$(echo ${mnemonic//,/ } | xargs || echo -n "")
        if (! $(isMnemonic "$mnemonic")) ; then
            if (! $(isMnemonic "$MASTER_MNEMONIC")) ; then
                echoErr "ERROR: Master mnemonic was not specified, keys can NOT be derived :(, please define '$mnemonicVariableName' variable in the '$MNEMONICS' file"
                exit 1
            fi
            mnemonic="$(bip39gen mnemonic --length=24 --entropy="$entropyHex" --verbose=true --hex=true)"
        fi
        setVar "$mnemonicVariableName" "$mnemonic" "$MNEMONICS" 1> /dev/null
    fi

    TMP_DUMP="/tmp/validator-key-gen.dump.tmp"
    if [ "${2,,}" == "val" ] ; then
        echoInfo "INFO: Ensuring $1 private key is generated"
        if [ ! -f "$valkeyPath" ] ; then # validator key is only re-generated if file is not present
            rm -fv "$valkeyPath"
            validator-key-gen --mnemonic="$mnemonic" --valkey="$valkeyPath" --nodekey=$TMP_DUMP --keyid=$TMP_DUMP
        fi
    elif [ "${2,,}" == "node" ] ; then
        echoInfo "INFO: Ensuring $1 nodekey files are generated"

        nodeIdVariableName="${1^^}_NODE_ID"
        nodeId="${!nodeIdVariableName}"
        
        if [ ! -f "$keyidPath" ] || [ ! -f "$nodekeyPath" ] ; then # node keys are only re-generated if any of keystore files is not present
            rm -fv "$keyidPath" "$nodekeyPath"
            validator-key-gen --mnemonic="$mnemonic" --valkey=$TMP_DUMP --nodekey="$nodekeyPath" --keyid="$keyidPath"
        fi
    
        newNodeId=$(cat $keyidPath)
        if [ -z "$nodeId" ] || [ "$nodeId" != "$newNodeId" ] ; then
            setVar "$nodeIdVariableName" "$newNodeId" "$MNEMONICS" 1> /dev/null
        fi
    elif [ "${2,,}" == "addr" ] ; then
        echoInfo "INFO: $1 address key does not require any kestore files"
    else
        echoErr "ERROR: Invalid key type $2, must be valkey, nodekey, addrkey"
        exit 1
    fi
    rm -fv $TMP_DUMP
}



if [ "$(globGet INFRA_MODE)" == "validator" ] ; then
    setVar VALIDATOR_ADDR_MNEMONIC "$MASTER_MNEMONIC" "$MNEMONICS" 1> /dev/null
    MnemonicGenerator "validator" "node" # validator node key (validator_node_key.json, validator_node_id.key -> VALIDATOR_NODE_ID)
    MnemonicGenerator "validator" "val" # validator block signing key (priv_validator_key.json)
elif [ "$(globGet INFRA_MODE)" == "seed" ] ; then
    MnemonicGenerator "seed" "node" # seed node key
elif [ "$(globGet INFRA_MODE)" == "sentry" ] ; then
    MnemonicGenerator "sentry" "node" # sentry node key (sentry_node_key.json, sentry_node_id.key -> SENTRY_NODE_ID)
fi

MnemonicGenerator "signer" "addr" # INTERX message signing key
MnemonicGenerator "test" "addr" # generic test key

source $MNEMONICS

echoInfo "INFO: Secrets loaded..."