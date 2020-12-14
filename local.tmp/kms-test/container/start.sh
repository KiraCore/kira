#!/bin/bash

exec 2>&1
set -e
set -x

tmkms init /root/.tmkms

# tmkms softsign keygen /root/.tmkms/secret_connection.key

cd /root/.tmkms/ && ls
tmkms softsign import ${SELF_KMS_RELEASE}/priv_validator_key.json /root/.tmkms/signing.key

sleep 10 && tmkms start -v -c ${SELF_KMS_RELEASE}/tmkms.toml
