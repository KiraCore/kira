#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} +
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +

STATUS_NGINX="$(service nginx status)"
SUB_STR="nginx is running"
if [[ "$STATUS_NGINX" != *"$SUB_STR"* ]]; then
  echo "Nginx is not running."
  nginx -t
  service nginx restart
  exit 1
fi

INDEX_HTML="$(curl http://127.0.0.1:80)"

echo $INDEX_HTML

INTERX_STATUS="$(curl http://interx:11000/api/status)"

echo $INTERX_STATUS
exit 0
