#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

PROMPT_SOURCE=$1

SNAPSHOT_TARGET=$(globGet SNAPSHOT_TARGET) && [ -z "$SNAPSHOT_TARGET" ] && SNAPSHOT_TARGET="${INFRA_MODE,,}"
echoNErr "Do you want to [K]eep old snapshots or [W]ipe all after backup is compleated: " && pressToContinue k w && SELECT=($(globGet OPTION))

if [ "${SELECT,,}" == "k" ] ; then
    echoInfo "INFO: Old snapshots will be disposed"
    globSet SNAPSHOT_KEEP_OLD "true"
else
    echoInfo "INFO: Old snapshots will be persisted"
    globSet SNAPSHOT_KEEP_OLD "false"
fi

while : ; do
    DEFAULT_SNAP_DIR=$KIRA_SNAP
    echoInfo "INFO: Default snapshot storage directory: $DEFAULT_SNAP_DIR"
    echoNErr "Input new snapshot storage directory or press [ENTER] for default: " && read DEFAULT_SNAP_DIR && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}"
    [ ! -z "$DEFAULT_SNAP_DIR"] && ( mkdir -p "$DEFAULT_SNAP_DIR" || echoErr "ERROR: Failed to create '$DEFAULT_SNAP_DIR' directory" )
    [ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
    if [ ! -d "$DEFAULT_SNAP_DIR" ] ; then
        echoErr "ERROR: Directory '$DEFAULT_SNAP_DIR' does not exist!"
        continue
    else
        echoInfo "INFO: Snapshot directory will be set to '$DEFAULT_SNAP_DIR'"
        KIRA_SNAP=$DEFAULT_SNAP_DIR
        break
    fi
done

echoWarn "WARNING: The '$SNAPSHOT_TARGET' container will be forcefully halted in order to safely backup blockchain state!"
echoNErr "Do you want to [U]n-halt '$SNAPSHOT_TARGET' container after backup is compleated or keep all processes [S]topped: " && pressToContinue u s && SELECT=($(globGet OPTION))

if [ "${SELECT,,}" == "u" ] ; then
    echoInfo "INFO: Container will be unhalted after backup is complete"
    globSet SNAPSHOT_UNHALT "true"
else
    echoInfo "INFO: Container processes will remain stopped after backup is complete"
    globSet SNAPSHOT_UNHALT "false"
fi

[ "$PROMPT_SOURCE" == "submenu" ] && \ 
    echoNErr "Do you want to [E]nable creation of a new backup after sync, [D]isable or e[X]it without making changes: " && \
    pressToContinue b e && SELECT=($(globGet OPTION))

[ "${SELECT,,}" == "x" ] && echoInfo "INFO: Exiting backup setup, snapshot will not be made..." && sleep 2 && exit 0

globSet "${SNAPSHOT_TARGET}_SYNCING" "true"
globSet SNAPSHOT_TARGET $SNAPSHOT_TARGET
[ "${SELECT,,}" == "e" ] && globSet SNAPSHOT_EXECUTE true
[ "${SELECT,,}" == "d" ] && globSet SNAPSHOT_EXECUTE false
setGlobEnv KIRA_SNAP $KIRA_SNAP

echoInfo "INFO: Snapsot task will be initiated and results saved to '$KIRA_SNAP' directory"
sleep 2
