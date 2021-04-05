#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-rebuild.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER=$1 && [ -z "$CONTAINER" ] && echoErr "ERROR: Container was not defined"

$KIRA_SCRIPTS/container-delete.sh "$CONTAINER"




