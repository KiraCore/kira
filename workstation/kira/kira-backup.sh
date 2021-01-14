#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm -f $FILE && nano $FILE && chmod 555 $FILE

echo -en "\e[31;1mInput halt height or press [ENTER] to snapshoot latest state: \e[0m"
read HALT_HEIGHT
DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshoot directory: $DEFAULT_SNAP_DIR"
SELECT="" && while [ "${SELECT,,}" != "n" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[31;1mDefine [N]ew default snapshoot directory or [C]continue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
[ "${SELECT,,}" == "n" ] && read "$DEFAULT_SNAP_DIR"
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP

echo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
echo "INFO: Making sure that snap direcotry exists..."
mkdir -p $DEFAULT_SNAP_DIR && echo "INFO: Success, snap direcotry is present"

SNAPSHOOT=""
if [ -f "$KIRA_SNAP_PATH" ] ; then
    SELECT="" && while [ "${SELECT,,}" != "s" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[31;1mChoose to [S]ync from snapshoot or [C]ontinue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
    if [ "${SELECT,,}" == "s" ] ; then
        SNAPSHOOTS=`ls $DEFAULT_SNAP_DIR/*.zip` # get all zip files in the snap directory
        SNAPSHOOTS_COUNT=${#SNAPSHOOTS[@]}
        SNAP_LATEST_PATH="$KIRA_SNAP_PATH"

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
        
        echo -en "\e[33;1mINFO: Snapshoot '$SNAPSHOOT' ($OPTION) was selected\e[0m" && echo ""
        echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    fi 
fi

CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
$KIRA_MANAGER/containers/start-snapshoot.sh "$HALT_HEIGHT" "$SNAPSHOOT"