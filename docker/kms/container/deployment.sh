#!/bin/bash

exec 2>&1
set -e
set -x

tmkms softsign keygen ~/.tmkms/secret_connection.key

cd ~/.tmkms/ && ls
tmkms softsign import /root/priv_validator_key.json ~/.tmkms/signing.key

tmkms start -c ${SELF_KMS_RELEASE}/tmkms.toml
