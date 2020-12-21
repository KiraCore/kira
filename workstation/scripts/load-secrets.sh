#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."

MNEMONICS="$KIRA_SECRETS/mnemonics.env"

mkdir -p "$KIRA_SECRETS"
touch $MNEMONICS

source $MNEMONICS

REGEN_PRIV_VALIDATOR_KEYS="false"
REGEN_VALIDATOR_NODE_KEYS="false"
REGEN_SENTRY_NODE_KEYS="false"

if [ -z "$SIGNER_MNEMONIC" ] ; then
    SIGNER_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="SIGNER_MNEMONIC=\"$SIGNER_MNEMONIC\"" --prefix="SIGNER_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
fi

if [ -z "$FAUCET_MNEMONIC" ] ; then
    FAUCET_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="FAUCET_MNEMONIC=\"$FAUCET_MNEMONIC\"" --prefix="FAUCET_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
fi

if [ -z "$VALIDATOR_NODE_ID_MNEMONIC" ] ; then
    REGEN_VALIDATOR_NODE_KEYS="true"
    VALIDATOR_NODE_ID_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="VALIDATOR_NODE_ID_MNEMONIC=\"$VALIDATOR_NODE_ID_MNEMONIC\"" --prefix="VALIDATOR_NODE_ID_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
fi

if [ -z "$SENTRY_NODE_ID_MNEMONIC" ] ; then
    REGEN_SENTRY_NODE_KEYS="true"
    SENTRY_NODE_ID_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="SENTRY_NODE_ID_MNEMONIC=\"$SENTRY_NODE_ID_MNEMONIC\"" --prefix="SENTRY_NODE_ID_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
fi

if [ -z "$PRIV_VALIDATOR_KEY_MNEMONIC" ] ; then
    REGEN_PRIV_VALIDATOR_KEYS="true"
    PRIV_VALIDATOR_KEY_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="PRIV_VALIDATOR_KEY_MNEMONIC=\"$PRIV_VALIDATOR_KEY_MNEMONIC\"" --prefix="PRIV_VALIDATOR_KEY_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
fi

# temp key is used to dump 
TMP_KEY="$KIRA_SECRETS/tmp.key"

# NOTE: private validator key must be generated from the separate mnemonic then node key !!!
PRIV_VAL_KEY_PATH="$KIRA_SECRETS/priv_validator_key.json" 

VAL_NODE_KEY_PATH="$KIRA_SECRETS/val_node_key.json"
SENT_NODE_KEY_PATH="$KIRA_SECRETS/sent_node_key.json"

VAL_NODE_ID_PATH="$KIRA_SECRETS/val_node_id.key"
SENT_NODE_ID_PATH="$KIRA_SECRETS/sent_node_id.key"

# re-generate keys

if [ "${REGEN_PRIV_VALIDATOR_KEYS,,}" == "true" ] || [ ! -f "$PRIV_VAL_KEY_PATH" ] ; then
    echo "INFO: Regenerating private validator key used for signing blocks"
    rm -fv "$PRIV_VAL_KEY_PATH" "$TMP_KEY"
    tmkms-key-import "${PRIV_VALIDATOR_KEY_MNEMONIC}" "$PRIV_VAL_KEY_PATH" "$TMP_KEY" "$TMP_KEY" "$TMP_KEY"
fi

if [ "${REGEN_VALIDATOR_NODE_KEYS,,}" == "true" ] || [ ! -f "$VAL_NODE_KEY_PATH" ] || [ ! -f "$VAL_NODE_ID_PATH" ] ; then
    echo "INFO: Regenerating validator node key & id"
    rm -fv "$VAL_NODE_KEY_PATH" "$VAL_NODE_ID_PATH" "$TMP_KEY"
    tmkms-key-import "${VALIDATOR_NODE_ID_MNEMONIC}" "$TMP_KEY" "$TMP_KEY" "$VAL_NODE_KEY_PATH" "$VAL_NODE_ID_PATH"
fi

if [ "${REGEN_SENTRY_NODE_KEYS,,}" == "true" ] || [ ! -f "$SENT_NODE_KEY_PATH" ] || [ ! -f "$SENT_NODE_ID_PATH" ] ; then
    echo "INFO: Regenerating sentry node key & id"
    rm -fv "$SENT_NODE_KEY_PATH" "$SENT_NODE_ID_PATH" "$TMP_KEY"
    tmkms-key-import "${SENTRY_NODE_ID_MNEMONIC}" "$TMP_KEY" "$TMP_KEY" "$SENT_NODE_KEY_PATH" "$SENT_NODE_ID_PATH"
fi

rm -fv "$TMP_KEY"
VALIDATOR_NODE_ID=$(cat $VAL_NODE_ID_PATH)
SENTRY_NODE_ID=$(cat $SENT_NODE_ID_PATH)

echo "INFO: Secrets loaded..."