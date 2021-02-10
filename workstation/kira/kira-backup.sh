#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

MIN_BLOCK_HEIGHT=$1
[[ ! $MIN_BLOCK_HEIGHT =~ ^[0-9]+$ ]] && MIN_BLOCK_HEIGHT=$VALIDATOR_MIN_HEIGHT
[[ ! $MIN_BLOCK_HEIGHT =~ ^[0-9]+$ ]] && MIN_BLOCK_HEIGHT=0
[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

echoNErr "Input halt height or press [ENTER] to snapshot latest state: " && read HALT_HEIGHT
DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshot directory: $DEFAULT_SNAP_DIR"

SELECT="." && while ! [[ "${SELECT,,}" =~ ^(n|c)$ ]] ; do echoNErr "Input [N]ew snapshot directory or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
[ "${SELECT,,}" == "n" ] && read "$DEFAULT_SNAP_DIR"
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP

echo "INFO: Snapshot directory will be set to '$DEFAULT_SNAP_DIR'"
echo "INFO: Making sure that snap direcotry exists..."
mkdir -p $DEFAULT_SNAP_DIR && echo "INFO: Success, snap direcotry is present"

while : ; do
    echoNErr "Input maximum number of snapshots to persist, press [ENTER] for default ($MAX_SNAPS): " && read NEW_MAX_SNAPS
    [ -z "${NEW_MAX_SNAPS##*[!0-9]*}" ] && NEW_MAX_SNAPS=$MAX_SNAPS
    ( [ -z "${NEW_MAX_SNAPS##*[!0-9]*}" ] || [ $NEW_MAX_SNAPS -lt 1 ] || [ $NEW_MAX_SNAPS -gt 1024 ] ) && echoWarn "WARNINIG: Max number of snapshots must be wihting range of 1 and 1024" && continue
    MAX_SNAPS=$NEW_MAX_SNAPS
    break
done

SNAPSHOT=""
SELECT="." && while ! [[ "${SELECT,,}" =~ ^(s|c)$ ]] ; do echoNErr "Choose to [S]ync from snapshot or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
if [ "${SELECT,,}" == "s" ] ; then
    # get all zip files in the snap directory
    SNAPSHOTS=`ls $DEFAULT_SNAP_DIR/*.zip` || SNAPSHOTS=""
    SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
    [ -z "$SNAPSHOTS" ] && SNAPSHOTS_COUNT="0"
    SNAP_LATEST_PATH="$KIRA_SNAP_PATH"
    
    if [ $SNAPSHOTS_COUNT -le 0 ] || [ -z "$SNAPSHOTS" ] ; then
        echoWarn "WARNING: No snapshots were found in the '$DEFAULT_SNAP_DIR' direcory"
        echoNErr "Press any key to abort..." && read -n 1 -s && echo ""
        exit 0
    else
        i=-1
        LAST_SNAP=""
        for s in $SNAPSHOTS ; do
            i=$((i + 1))
            echo "[$i] $s"
            LAST_SNAP=$s
        done
        
        [ ! -f "$SNAP_LATEST_PATH" ] && SNAP_LATEST_PATH=$LAST_SNAP
        echo "INFO: Latest snapshot: '$SNAP_LATEST_PATH'"
        
        OPTION=""
        while : ; do
            read -p "Input snapshot number 0-$i (Default: latest): " OPTION
            [ -z "$OPTION" ] && break
            [ "${OPTION,,}" == "latest" ] && break
            [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
        done
        
        if [ ! -z "$OPTION" ] && [ "${OPTION,,}" != "latest" ] ; then
            SNAPSHOTS=( $SNAPSHOTS )
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
CDHelper text lineswap --insert="MAX_SNAPS=$MAX_SNAPS" --prefix="MAX_SNAPS=" --path=$ETC_PROFILE --append-if-found-not=True