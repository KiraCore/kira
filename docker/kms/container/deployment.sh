#!/bin/bash

exec 2>&1
set -e
set -x

mkdir ~/.tmkms/

tmkms softsign keygen ~/.tmkms/secret_connection.key

tmkms start -c ${SELF_KMS_RELEASE}/tmkms.toml
