#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

AUTO_RECOVER="$1"

if [ "${AUTO_RECOVER,,}" == "false" ] ; then
    SELECT="" && while [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[31;1m[R]ecover from existing snapshoot or [S]ync new blockchain state: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
    
    if [ "${SELECT,,}" == "s" ] ; then
        echo "INFO: Blockchain state will NOT be recovered from the snapshoot"
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        exit 0 
    fi
else
    echo "INFO: Auto recovery mode enabled"
fi

DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshoot directory: $DEFAULT_SNAP_DIR"
SELECT="" && while [ "${SELECT,,}" != "k" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[31;1m[K]eep default snapshoot directory or [C]hange: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

[ "${SELECT,,}" == "c" ] && read "$DEFAULT_SNAP_DIR" && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}" # read and trim leading slash
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
echo -en "\e[31;1mINFO: Press any key to save changes or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""

if [ "$KIRA_SNAP" != "$DEFAULT_SNAP_DIR" ] ; then
    CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
    KIRA_SNAP=$DEFAULT_SNAP_DIR
fi

# get all zip files in the snap directory
SNAPSHOOTS=`ls $KIRA_SNAP/*.zip` || SNAPSHOOTS=""
SNAPSHOOTS_COUNT=${#SNAPSHOOTS[@]}
SNAP_LATEST_PATH="$KIRA_SNAP_PATH"

if [ $SNAPSHOOTS_COUNT -le 0 ] || [ -z "$SNAPSHOOTS" ] ; then
  echoWarn "WARNING: No snapshoots were found in the '$KIRA_SNAP' direcory, state recovery will be aborted"
  echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
  exit 0
fi

echo -en "\e[31;1mPlease select snapshoot to recover from:\e[0m" && echo ""

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
set -x

CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

