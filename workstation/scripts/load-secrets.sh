#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
echoInfo "INFO: Loading secrets..."

MNEMONICS="$KIRA_SECRETS/mnemonics.env"

mkdir -p "$KIRA_SECRETS"
touch $MNEMONICS

REGEN_PRIV_VALIDATOR_KEYS="false"
REGEN_VALIDATOR_NODE_KEYS="false"
REGEN_SENTRY_NODE_KEYS="false"

function MnemonicGenerator() {
    loadGlobEnvs
    MNEMONICS="$KIRA_SECRETS/mnemonics.env"
    source $MNEMONICS

    mnemonicVariableName="${1^^}_${2^^}_MNEMONIC"

    valkeyPath="$KIRA_SECRETS/priv_${1,,}_key.json"
    nodekeyPath="$KIRA_SECRETS/${1,,}_node_key.json"
    keyidPath="$KIRA_SECRETS/${1,,}_node_id.key"

    mnemonic="${!mnemonicVariableName}"
    mnemonic=$(echo "$mnemonic" | xargs || echo -n "")

    if (! $(isMnemonic "$mnemonic")) ; then # if mnemonic is not present then generate new one
        echoInfo "INFO: $mnemonicVariableName was not found, regenerating..."
        mnemonic=$(echo ${mnemonic//,/ } | xargs || echo -n "")
        (! $(isMnemonic "$mnemonic")) && mnemonic="$(bip39gen mnemonic --length=24 --verbose=false)"
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

MnemonicGenerator "signer" "addr" # INTERX message signing key
MnemonicGenerator "validator" "addr" # validator controller key
MnemonicGenerator "test" "addr" # generic test key
MnemonicGenerator "sentry" "node" # sentry node key (sentry_node_key.json, sentry_node_id.key -> SENTRY_NODE_ID)
MnemonicGenerator "seed" "node" # seed node key
MnemonicGenerator "validator" "node" # validator node key (validator_node_key.json, validator_node_id.key -> VALIDATOR_NODE_ID)
# NOTE: private validator key is generated from the separate mnemonic then node key or address !!!
MnemonicGenerator "validator" "val" # validator block signing key (priv_validator_key.json)

source $MNEMONICS

echoInfo "INFO: Secrets loaded..."