#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

[ "${INFRA_MODE,,}" == "latest" ] && SNAPSHOT_TARGET="validator" || SNAPSHOT_TARGET="${INFRA_MODE,,}"

echoNErr "Do you want to [K]eep old snapshots or [W]ipe all after backup is compleated: " && pressToContinue k w && SELECT=($(globGet OPTION))

if [ "${SELECT,,}" == "k" ] ; then
    echoInfo "INFO: Old snapshots will be disposed"
    globSet SNAPSHOT_KEEP_OLD "true"
else
    echoInfo "INFO: Old snapshots will be persisted"
    globSet SNAPSHOT_KEEP_OLD "false"
fi

echoNErr "Do you want to [U]n-halt '$SNAPSHOT_TARGET' container after backup is compleated or keep all processes [S]topped: " && pressToContinue u s && SELECT=($(globGet OPTION))

if [ "${SELECT,,}" == "u" ] ; then
    echoInfo "INFO: Container will be unhalted after backup is complete"
    globSet SNAPSHOT_UNHALT "true"
else
    echoInfo "INFO: Container processes will remain stopped after backup is complete"
    globSet SNAPSHOT_UNHALT "false"
fi

echoWarn "WARNING: The '$SNAPSHOT_TARGET' container will be forcefully halted in order to safely backup blockchain state!"
[ "${SNAPSHOT_TARGET,,}" == "validator" ] && echoWarn "WARNING: IT IS RECCOMENDED THAT YOU ENABLE MAINTENANCE MODE BEFORE YOU PROCEED!"
echoNErr "Do you want to continue and create a new [B]ackup, or [E]xit: " && pressToContinue b e && SELECT=($(globGet OPTION))

[ "${SELECT,,}" == "e" ] && echoInfo "INFO: Exiting backup setup, snapshot will not be made..." && sleep 3 && exit 0

globSet "${SNAPSHOT_TARGET}_SYNCING" "true"
globSet SNAPSHOT_TARGET $SNAPSHOT_TARGET
globSet SNAPSHOT_EXECUTE true

echoInfo "INFO: Snapsot task started, results will be saed to '$KIRA_SNAP' directory"
sleep 3
