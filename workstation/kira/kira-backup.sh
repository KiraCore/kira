#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

MIN_BLOCK_HEIGHT=$1
[[ ! $MIN_BLOCK_HEIGHT =~ ^[0-9]+$ ]] && MIN_BLOCK_HEIGHT=$VALIDATOR_MIN_HEIGHT
[[ ! $MIN_BLOCK_HEIGHT =~ ^[0-9]+$ ]] && MIN_BLOCK_HEIGHT=0

echoNErr "Input halt height or press [ENTER] to snapshoot latest state: " && read HALT_HEIGHT
DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshoot directory: $DEFAULT_SNAP_DIR"

SELECT="." && while ! [[ "${SELECT,,}" =~ ^(n|c)$ ]] ; do echoNErr "Input [N]ew snapshoot directory or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
[ "${SELECT,,}" == "n" ] && read "$DEFAULT_SNAP_DIR"
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP

echo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
echo "INFO: Making sure that snap direcotry exists..."
mkdir -p $DEFAULT_SNAP_DIR && echo "INFO: Success, snap direcotry is present"

while : ; do
    [ -z "$MAX_SNAPS" ] && MAX_SNAPS=3
    echoNErr "Input maximum number of snapshoots to persist, press [ENTER] for default ($MAX_SNAPS): " && MAX_SNAPS
    ( [ -z "${MAX_SNAPS##*[!0-9]*}" ] || [ $MAX_SNAPS -lt 1 ] || [ $MAX_SNAPS -gt 1024 ] ) && echoWarn "WARNINIG: Max number of snapshoots must be wihting range of 1 and 1024" && continue
    break
done

SNAPSHOOT=""
SELECT="." && while ! [[ "${SELECT,,}" =~ ^(s|c)$ ]] ; do echoNErr "Choose to [S]ync from snapshoot or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
if [ "${SELECT,,}" == "s" ] ; then
    # get all zip files in the snap directory
    SNAPSHOOTS=`ls $DEFAULT_SNAP_DIR/*.zip` || SNAPSHOOTS=""
    SNAPSHOOTS_COUNT=${#SNAPSHOOTS[@]}
    [ -z "$SNAPSHOOTS" ] && SNAPSHOOTS_COUNT="0"
    SNAP_LATEST_PATH="$KIRA_SNAP_PATH"
    
    if [ $SNAPSHOOTS_COUNT -le 0 ] || [ -z "$SNAPSHOOTS" ] ; then
        echoWarn "WARNING: No snapshoots were found in the '$DEFAULT_SNAP_DIR' direcory"
        echoNErr "Press any key to abort..." && read -n 1 -s && echo ""
        exit 0
    else
        i=-1
        LAST_SNAP=""
        for s in $SNAPSHOOTS ; do
            i=$((i + 1))
            echo "[$i] $s"
            LAST_SNAP=$s
        done
        
        [ ! -f "$SNAP_LATEST_PATH" ] && SNAP_LATEST_PATH=$LAST_SNAP
        echo "INFO: Latest snapshoot: '$SNAP_LATEST_PATH'"
        
        OPTION=""
        while : ; do
            read -p "Input snapshoot number 0-$i (Default: latest): " OPTION
            [ -z "$OPTION" ] && break
            [ "${OPTION,,}" == "latest" ] && break
            [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
        done
        
        if [ ! -z "$OPTION" ] && [ "${OPTION,,}" != "latest" ] ; then
            SNAPSHOOTS=( $SNAPSHOOTS )
            SNAPSHOOT=${SNAPSHOOTS[$OPTION]}
        else
            OPTION="latest"
            SNAPSHOOT=$SNAP_LATEST_PATH
        fi
        
        echoInfo "INFO: Snapshoot '$SNAPSHOOT' ($OPTION) was selected"
    fi
     
    echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
fi

CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
$KIRA_MANAGER/containers/start-snapshoot.sh "$HALT_HEIGHT" "$SNAPSHOOT"
CDHelper text lineswap --insert="MAX_SNAPS=$MAX_SNAPS" --prefix="MAX_SNAPS=" --path=$ETC_PROFILE --append-if-found-not=True