#!/bin/bash
exec 2>&1
set -e
# quick edit: FILE="$KIRA_SCRIPTS/container-id.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

#id=$(timeout 1 docker inspect --format="{{.Id}}" "$1" 2> /dev/null || echo "")
id=$(docker ps --no-trunc -aqf "name=^${1}$" 2> /dev/null || echo "")
if [ -z "$id" ] || [[ "$id" == *"sha256"* ]] ; then
    echo ""
else
    echo "$id"
fi 

# STATUS=$(docker inspect $($KIRA_SCRIPTS/container-id.sh "frontend") | jq -rc '.[0].State.Status')