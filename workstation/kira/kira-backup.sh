#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

SNAP_EXPOSE="$(globGet SNAP_EXPOSE)"
KIRA_SNAP_PATH="$(globGet KIRA_SNAP_PATH)"
SNAPSHOT_TARGET="$(globGet SNAPSHOT_TARGET)" 
[ -z "$SNAPSHOT_TARGET" ] && SNAPSHOT_TARGET="$(globGet INFRA_MODE)"

while : ; do
    clear
    if (! $(isFileEmpty $KIRA_SNAP_PATH)) ; then
        echoInfo "Snapshot file was found :)"
        echoInfo "   LATEST SNAPSHOT FILE: $KIRA_SNAP_PATH"
        echoInfo "     FILE SNAPSHOT SIZE: $(prettyBytes $(fileSize $KIRA_SNAP_PATH))"
        echoInfo " DEFAULT SNAP DIRECTORY: $KIRA_SNAP"
        echoInfo "        IS FILE EXPOSED: $SNAP_EXPOSE"

        if [ "$SNAP_EXPOSE" != "true" ] ; then
            echoNC "bli;whi" "\n[E]xpose existing snapshot, change [D]irectory, [C]reate new snapshot or e[X]it: " 
            pressToContinue e c x
        else
            echoNC "bli;whi" "\n[H]ide exposed snapshot, change [D]irectory, [C]reate new snapshot or e[X]it: " 
            pressToContinue h c x
        fi
    else
        echoInfo "No snapshots were found :("
        echoNC "bli;whi" "\n[C]reate new snapshot, change [D]irectory, or e[X]it: " 
        pressToContinue c d x
    fi

    SELECT="$(globGet OPTION)"

    [ "$SELECT" == "x" ] && echoInfo "INFO: Exiting backup setup..." && sleep 2 && exit 0

    if [ "$SELECT" == "e" ] ; then
        SNAP_EXPOSE="true"
        globSet SNAP_EXPOSE "$SNAP_EXPOSE"
    elif [ "$SELECT" == "h" ] ; then
        SNAP_EXPOSE="false"
        globSet SNAP_EXPOSE "$SNAP_EXPOSE"
    elif [ "$SELECT" == "d" ] ; then
        echoNErr "Input new snapshot storage directory or press [ENTER] for default: " && read DEFAULT_SNAP_DIR && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}"
        [ ! -z "$DEFAULT_SNAP_DIR"] && ( mkdir -p "$DEFAULT_SNAP_DIR" || echoErr "ERROR: Failed to create '$DEFAULT_SNAP_DIR' directory" )
        [ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
        if [ ! -d "$DEFAULT_SNAP_DIR" ] ; then
            echoErr "ERROR: Directory '$DEFAULT_SNAP_DIR' does not exist!"
            sleep 3
        else
            echoInfo "INFO: Snapshot directory will be set to '$DEFAULT_SNAP_DIR'"
            KIRA_SNAP="$DEFAULT_SNAP_DIR"
            setGlobEnv KIRA_SNAP "$KIRA_SNAP"
            sleep 3
        fi
    elif [ "$SELECT" == "c" ] ; then
        break
    fi
done


echoWarn "WARNING: Snapshot creation will only be started after your node stopped syncing!"

# wipes snapshot directory, before creting new snaps
globSet SNAPSHOT_KEEP_OLD "false"

# unhalts container after snapshot is complete
globSet SNAPSHOT_UNHALT "true"
globSet "${SNAPSHOT_TARGET}_SYNCING" "true"
globSet SNAPSHOT_TARGET "$SNAPSHOT_TARGET"
globSet SNAPSHOT_EXECUTE true

echoInfo "INFO: Snapsot task will be initiated and results saved to '$KIRA_SNAP' directory"
sleep 2
