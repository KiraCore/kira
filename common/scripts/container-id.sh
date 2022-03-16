#!/usr/bin/env bash
exec 2>&1
set -e
# quick edit: FILE="$KIRA_SCRIPTS/container-id.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

#id=$(timeout 1 docker inspect --format="{{.Id}}" "$1" 2> /dev/null || echo -n "")
id=$(timeout 3 docker ps --no-trunc -aqf "name=^${1}$" 2> /dev/null || echo -n "")
if [ -z "$id" ] || [[ "$id" == *"sha256"* ]] ; then
    echo -n ""
else
    echo "$id"
fi 
