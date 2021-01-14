#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e


SELECT="" && while [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[33;1mChoose to [R]ecover from existing snapshoot or [S]ync new blockchain state: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

[ "${SELECT,,}" == "s" ] && echo "INFO: Blockchain state will NOT be recovered from the snapshoot" && exit 0 

DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Default snapshoot directory: $DEFAULT_SNAP_DIR"
SELECT="" && while [ "${SELECT,,}" != "k" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[33;1m[K]eep default snapshoot directory or [C]hange: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

[ "${SELECT,,}" == "c" ] && read "$DEFAULT_SNAP_DIR" && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}" # read and trim leading slash
[ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
echo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
echo -en "\e[31;1mINFO: Press any key to save changes or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""

if [ "$KIRA_SNAP" != "$DEFAULT_SNAP_DIR" ] ; then
    CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
    KIRA_SNAP=$DEFAULT_SNAP_DIR
fi

SNAPSHOOTS=`ls $KIRA_SNAP/*.zip` # get all zip files in the snap directory
SNAPSHOOTS=( $SNAPSHOOTS )
SNAPSHOOTS_COUNT=${#SNAPSHOOTS[@]}

if [ $SNAPSHOOTS_COUNT -le 0 ] ; then
  echo "INFO: No snapshoots were found in the '$KIRA_SNAP' direcory, state recovery will be aborted"
  echo -en "\e[31;1mINFO: Press any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
  exit 0
fi

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"
SNAP_LATEST_NAME=$(cat $SNAP_LATEST || echo "")
SNAP_LATEST_PATH="$SNAP_STATUS/$SNAP_LATEST_NAME"
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
    OPTION="latest"
    SNAPSHOOT=${SNAPSHOOTS[$OPTION]}
else
    SNAPSHOOT=$SNAP_LATEST_PATH
fi

echo -en "\e[33;1mINFO: Snapshoot '$SNAPSHOOT' ($OPTION) was selected\e[0m" && echo ""
echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
set -x

CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

