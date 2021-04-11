#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

MIN_BLOCK_HEIGHT=$1
(! $(isNaturalNumber "$MIN_BLOCK_HEIGHT")) && MIN_BLOCK_HEIGHT=$VALIDATOR_MIN_HEIGHT
(! $(isNaturalNumber "$MIN_BLOCK_HEIGHT")) && MIN_BLOCK_HEIGHT=0
(! $(isNaturalNumber "$MAX_SNAPS")) && MAX_SNAPS=2

SELECT="." && while ! [[ "${SELECT,,}" =~ ^(b|c)$ ]]; do echoNErr "Do you want to create a new [B]ackup, or [C]hange auto-backup configuration?: " && read -d'' -s -n1 SELECT && echo ""; done

while :; do
    echoNErr "Input maximum number of snapshots to persist, press [ENTER] for default ($MAX_SNAPS): " && read NEW_MAX_SNAPS
    (! $(isNaturalNumber "$NEW_MAX_SNAPS")) && NEW_MAX_SNAPS=$MAX_SNAPS
    ([ $NEW_MAX_SNAPS -lt 1 ] || [ $NEW_MAX_SNAPS -gt 1024 ]) && echoWarn "WARNINIG: Max number of snapshots must be wihting range of 1 and 1024" && continue
    MAX_SNAPS=$NEW_MAX_SNAPS
    CDHelper text lineswap --insert="MAX_SNAPS=$MAX_SNAPS" --prefix="MAX_SNAPS=" --path=$ETC_PROFILE --append-if-found-not=True
    break
done

if [ "${SELECT,,}" == "c" ]; then
    while :; do
        [ "${AUTO_BACKUP_ENABLED,,}" == "false" ] && AUTO_BACKUP_INTERVAL=0
        echoNErr "How often (in hours) auto-backup should be performed? Input 0 to disable auto-backup or press [ENTER] for default ($AUTO_BACKUP_INTERVAL): " && read NEW_AUTO_BACKUP_INTERVAL
        if [ -z "$NEW_AUTO_BACKUP_INTERVAL" ] ; then
            echoInfo "INFO: Backup interval will not be chaned"
            break
        fi
        
        (! $(isInteger "$NEW_AUTO_BACKUP_INTERVAL")) && echoWarn "WARNING: Input must be a valid integer" && continue
        [ $NEW_AUTO_BACKUP_INTERVAL -lt 0 ] && echoWarn "WARNING: Input must be an integer larger or equal to 0" && continue
        [ "$NEW_AUTO_BACKUP_INTERVAL" == "0" ] && echoInfo "INFO: Auto backup will be disabled" && AUTO_BACKUP_ENABLED="false" && break
        echoInfo "INFO: Auto backup is enabled and will be executed every ${NEW_AUTO_BACKUP_INTERVAL}h"
        AUTO_BACKUP_ENABLED="true"
        AUTO_BACKUP_INTERVAL="$NEW_AUTO_BACKUP_INTERVAL"
        break
    done
    
    CDHelper text lineswap --insert="AUTO_BACKUP_ENABLED=$AUTO_BACKUP_ENABLED" --prefix="AUTO_BACKUP_ENABLED=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="AUTO_BACKUP_INTERVAL=$AUTO_BACKUP_INTERVAL" --prefix="AUTO_BACKUP_INTERVAL=" --path=$ETC_PROFILE --append-if-found-not=True
    exit 0
fi


echoNErr "Input halt height or press [ENTER] to snapshot latest state: " && read HALT_HEIGHT
echoInfo "INFO: Default snapshot directory: $KIRA_SNAP"

echoNErr "Input new snapshot directory or press [ENTER] to continue: " && read DEFAULT_SNAP_DIR
[ ! -z "$DEFAULT_SNAP_DIR" ] && [ ! -d "$DEFAULT_SNAP_DIR" ] && echoWarn "WARNING: Directory '$DEFAULT_SNAP_DIR' was not found" && DEFAULT_SNAP_DIR=""
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP

echoInfo "INFO: Snapshot directory will be set to '$DEFAULT_SNAP_DIR'"
echoInfo "INFO: Making sure that snap direcotry exists..."
mkdir -p $DEFAULT_SNAP_DIR && echo "INFO: Success, snap direcotry is present"

SNAPSHOT=""
SELECT="." && while ! [[ "${SELECT,,}" =~ ^(s|c)$ ]]; do echoNErr "Choose to [S]ync from snapshot or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
if [ "${SELECT,,}" == "s" ]; then
    # get all zip files in the snap directory
    SNAPSHOTS=$(ls $DEFAULT_SNAP_DIR/*.zip) || SNAPSHOTS=""
    SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
    [ -z "$SNAPSHOTS" ] && SNAPSHOTS_COUNT="0"
    SNAP_LATEST_PATH="$KIRA_SNAP_PATH"
          
    if [ $SNAPSHOTS_COUNT -le 0 ] || [ -z "$SNAPSHOTS" ]; then
        echoWarn "WARNING: No snapshots were found in the '$DEFAULT_SNAP_DIR' direcory"
        echoNErr "Press any key to abort..." && read -n 1 -s && echo ""
        exit 0
    else
        i=-1
        LAST_SNAP=""
        for s in $SNAPSHOTS; do
            i=$((i + 1))
            echo "[$i] $s"
            LAST_SNAP=$s
        done
          
        [ ! -f "$SNAP_LATEST_PATH" ] && SNAP_LATEST_PATH=$LAST_SNAP
        echo "INFO: Latest snapshot: '$SNAP_LATEST_PATH'"
              
        OPTION=""
        while :; do
            read -p "Input snapshot number 0-$i (Default: latest): " OPTION
            [ -z "$OPTION" ] && break
            [ "${OPTION,,}" == "latest" ] && break
            [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
        done
              
        if [ ! -z "$OPTION" ] && [ "${OPTION,,}" != "latest" ]; then
            SNAPSHOTS=($SNAPSHOTS)
            SNAPSHOT=${SNAPSHOTS[$OPTION]}
        else
            OPTION="latest"
            SNAPSHOT=$SNAP_LATEST_PATH
        fi
              
        echoInfo "INFO: Snapshot '$SNAPSHOT' ($OPTION) was selected"
    fi
         
    echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
fi

CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
$KIRA_MANAGER/containers/start-snapshot.sh "$HALT_HEIGHT" "$SNAPSHOT"


