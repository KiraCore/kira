#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-backup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

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

SYNC="false"
if [ -f "$KIRA_SNAP_PATH" ] ; then
    SELECT="" && while [ "${SELECT,,}" != "s" ] && [ "${SELECT,,}" != "c" ]; do echo -en "\e[31;1mChoose to [S]ync from snapshoot or [C]ontinue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
    [ "${SELECT,,}" == "s" ] && SYNC="true"
fi

CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
$KIRA_MANAGER/containers/start-snapshoot.sh "$HALT_HEIGHT" "$SYNC" || echo "ERROR: Snapshoot failed"