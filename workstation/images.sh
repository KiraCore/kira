#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/images.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SRIPT_START_TIME="$(date -u +%s)"
cd $HOME

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: IMAGES BUILD SCRIPT                 |"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Starting images build..."

$KIRAMGR_SCRIPTS/update-base-image.sh
$KIRAMGR_SCRIPTS/update-kira-image.sh & 
$KIRAMGR_SCRIPTS/update-interx-image.sh &

if [ "${INFRA_MODE,,}" != "validator" ] ; then
    $KIRAMGR_SCRIPTS/update-frontend-image.sh &
fi

echoInfo "INFO: Waiting for images build to finalize..."
wait
echoInfo "INFO: Images build was finalized.."

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: IMAGES BUILD SCRIPT                |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x