#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring KMS..."
EXECUTED_CHECK="/root/executed"

if [ -f "$EXECUTED_CHECK" ]; then
  sleep 10 && tmkms start -v -c /root/.tmkms/tmkms.toml
else
  tmkms init /root/.tmkms

  # tmkms softsign keygen /root/.tmkms/secret_connection.key
  mv $COMMON_DIR/tmkms.toml /root/.tmkms/

  cd /root/.tmkms/ && ls
  tmkms softsign import $COMMON_DIR/priv_validator_key.json /root/.tmkms/signing.key

  touch $EXECUTED_CHECK
  sleep 10 && tmkms start -v -c /root/.tmkms/tmkms.toml
fi
