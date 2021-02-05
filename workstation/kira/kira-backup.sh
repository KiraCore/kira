#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

echo -en "\e[31;1mInput halt height or press [ENTER] to snapshoot latest state: \e[0m"
read HALT_HEIGHT
DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshoot directory: $DEFAULT_SNAP_DIR"
SELECT="." && while [ "${SELECT,,}" != "n" ] && [ ! -z "${SELECT,,}" ]; do echoNErr -en "\e[31;1mInput [N]ew snapshoot directory or press [ENTER] to continue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
[ "${SELECT,,}" == "n" ] && read "$DEFAULT_SNAP_DIR"
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP

echo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
echo "INFO: Making sure that snap direcotry exists..."
mkdir -p $DEFAULT_SNAP_DIR && echo "INFO: Success, snap direcotry is present"

SNAPSHOOT=""
SELECT="." && while [ "${SELECT,,}" != "s" ] && [ ! -z "${SELECT,,}" ]; do echoNErr "Choose to [S]ync from snapshoot or press [ENTER] to continue: " && read -d'' -s -n1 SELECT && echo ""; done
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