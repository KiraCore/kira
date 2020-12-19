#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."

MNEMONICS="$KIRA_SECRETS/mnemonics.env"

touch $MNEMONICS

source $MNEMONICS

if [ -z "$SIGNER_MNEMONIC" ] ; then
    SIGNER_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="SIGNER_MNEMONIC=$SIGNER_MNEMONIC" --prefix="SIGNER_MNEMONIC=" --path=$ETC_PROFILE --append-if-found-not=True --silent=true
fi

if [ -z "$FAUCET_MNEMONIC" ] ; then
    FAUCET_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="FAUCET_MNEMONIC=$FAUCET_MNEMONIC" --prefix="FAUCET_MNEMONIC=" --path=$ETC_PROFILE --append-if-found-not=True --silent=true
fi

if [ -z "$VALIDATOR_NODE_ID_MNEMONIC" ] ; then
    VALIDATOR_NODE_ID_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="VALIDATOR_NODE_ID_MNEMONIC=$VALIDATOR_NODE_ID_MNEMONIC" --prefix="VALIDATOR_NODE_ID_MNEMONIC=" --path=$ETC_PROFILE --append-if-found-not=True --silent=true
fi

if [ -z "$SENTRY_NODE_ID_MNEMONIC" ] ; then
    SENTRY_NODE_ID_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="SENTRY_NODE_ID_MNEMONIC=$SENTRY_NODE_ID_MNEMONIC" --prefix="SENTRY_NODE_ID_MNEMONIC=" --path=$ETC_PROFILE --append-if-found-not=True --silent=true
fi

if [ -z "$PRIV_VALIDATOR_KEY_MNEMONIC" ] ; then
    PRIV_VALIDATOR_KEY_MNEMONIC="$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')"
    CDHelper text lineswap --insert="PRIV_VALIDATOR_KEY_MNEMONIC=$PRIV_VALIDATOR_KEY_MNEMONIC" --prefix="PRIV_VALIDATOR_KEY_MNEMONIC=" --path=$ETC_PROFILE --append-if-found-not=True --silent=true
fi

echo "INFO: Secrets loaded..."