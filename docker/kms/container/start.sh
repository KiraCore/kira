#!/bin/bash

exec 2>&1
set -e
set -x

tmkms init /root/.tmkms

# tmkms softsign keygen /root/.tmkms/secret_connection.key
mv $COMMON_DIR/kms/tmkms.toml /root/.tmkms/

cd /root/.tmkms/ && ls
tmkms softsign import $COMMON_DIR/priv_validator_key.json /root/.tmkms/signing.key

sleep 10 && tmkms start -v -c /root/.tmkms/tmkms.toml
