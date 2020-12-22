#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring frontend..."

HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

nginx -g 'daemon off;'
