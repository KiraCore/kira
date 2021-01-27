#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

echo "INFO: Loading secrets..."

MNEMONICS="$KIRA_SECRETS/mnemonics.env"

mkdir -p "$KIRA_SECRETS"
touch $MNEMONICS

source $MNEMONICS

REGEN_PRIV_VALIDATOR_KEYS="false"
REGEN_VALIDATOR_NODE_KEYS="false"
REGEN_SENTRY_NODE_KEYS="false"
REGEN_SNAPSHOOT_NODE_KEYS="false"

function MnemonicGenerator() {
    set +e && source "/etc/profile" &>/dev/null && set -e
    source $KIRA_MANAGER/utils.sh

    MNEMONICS="$KIRA_SECRETS/mnemonics.env"
    source $MNEMONICS

    mnemonicVariableName="${1^^}_${2^^}_MNEMONIC"

    valkeyPath="$KIRA_SECRETS/priv_${1,,}_key.json"
    nodekeyPath="$KIRA_SECRETS/${1,,}_node_key.json"
    keyidPath="$KIRA_SECRETS/${1,,}_node_id.key"

    mnemonic="${!mnemonicVariableName}"

    if [ -z "$mnemonic" ] ; then # if mnemonic is not present then generate new one
        echoInfo "INFO: $mnemonicVariableName was not found, regenerating..."
        mnemonic="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq -r '.[0].mnemonic')"
        CDHelper text lineswap --insert="$mnemonicVariableName=\"$mnemonic\"" --prefix="$mnemonicVariableName=" --path=$MNEMONICS --append-if-found-not=True --silent=true
    fi

    if [ "${2,,}" == "val" ] ; then
        echoInfo "INFO: Ensuring $1 private key is generated"
        if [ ! -f "$valkeyPath" ] ; then # validator key is only re-generated if file is not present
            rm -fv "$valkeyPath"
            priv-key-gen --mnemonic="$mnemonic" --valkey="$valkeyPath" --nodekey=/dev/null --keyid=/dev/null
        fi
    elif [ "${2,,}" == "node" ] ; then
        echoInfo "INFO: Ensuring $1 nodekey files are generated"

        nodeIdVariableName="${1^^}_NODE_ID"
        nodeId="${!nodeIdVariableName}"
        
        if [ ! -f "$keyidPath" ] || [ ! -f "$nodekeyPath" ] ; then # node keys are only re-generated if any of keystore files is not present
            rm -fv "$keyidPath" "$nodekeyPath"
            priv-key-gen --mnemonic="$mnemonic" --valkey=/dev/null --nodekey="$nodekeyPath" --keyid="$keyidPath"
        fi
    
        newNodeId=$(cat $keyidPath)
        if [ -z "$nodeId" ] || [ "$nodeId" != "$newNodeId" ] ; then
            CDHelper text lineswap --insert="$nodeIdVariableName=\"$newNodeId\"" --prefix="$nodeIdVariableName=" --path=$MNEMONICS --append-if-found-not=True --silent=true
        fi
    elif [ "${2,,}" == "addr" ] ; then
        echoInfo "INFO: $1 address key does not require any kestore files"
    else
        echoErr "ERROR: Invalid key type $2, must be valkey, nodekey, addrkey"
        exit 1
    fi
}

MnemonicGenerator "signer" "addr" # INTERX message signing key
MnemonicGenerator "faucet" "addr" # INTERX faucet key
MnemonicGenerator "frontend" "addr" # frontend key
MnemonicGenerator "validator" "addr" # validator controller key
MnemonicGenerator "test" "addr" # generic test key
MnemonicGenerator "sentry" "node" # sentry node key (sentry_node_key.json, sentry_node_id.key -> SENTRY_NODE_ID)
MnemonicGenerator "priv_sentry" "node" # private sentry node key
MnemonicGenerator "snapshoot" "node" # snapshoot sentry node key (snapshoot_node_key.json, snapshoot_node_id.key -> SNAPSHOOT_NODE_ID)
MnemonicGenerator "validator" "node" # validator node key (validator_node_key.json, validator_node_id.key -> VALIDATOR_NODE_ID)
# NOTE: private validator key is generated from the separate mnemonic then node key or address !!!
MnemonicGenerator "validator" "val" # validator block signing key (priv_validator_key.json)

source $MNEMONICS

echoInfo "INFO: Secrets loaded..."