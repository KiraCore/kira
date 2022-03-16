#!/usr/bin/env bash
exec 2>&1
set -e
# quick edit: FILE="$KIRA_SCRIPTS/container-running.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

# NOTE: $1 (arg 1) must be a valid container id
if [ -z "$1" ] ; then
    echo "false"
else
    STATUS=$(timeout 2 docker inspect "$1" 2> /dev/null | grep -Eo '"Status"[^,]*' 2> /dev/null | grep -Eo '[^:]*$' 2> /dev/null | xargs 2> /dev/null | awk '{print $1;}' 2> /dev/null || echo -n "")
    if [ "${STATUS,,}" == "running" ] || [ "${STATUS,,}" == "starting" ] ; then
        echo "true"
    else
        echo "false"
    fi
fi

