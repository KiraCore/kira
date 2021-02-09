#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/chain-id-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NEW_NETWORK_NAME=""

echo "INFO: Startnet network name selector!"
while : ; do
    echoInfo "INFO: Network name (chai-id) should have format <name>-<number>, e.g. mynetwork-1"
    echoNErr "Input name of your NEW network (chain-id): " && read NEW_NETWORK_NAME

    NEW_NETWORK_NAME="${NEW_NETWORK_NAME,,}"
    ARR=( $(echo "$NEW_NETWORK_NAME" | tr "-" "\n") ) && ARR_LEN=${#ARR[@]}
    [ ${#NEW_NETWORK_NAME} -gt 16 ] && echoWarn "WARNING: Network name can't be longer than 16 characters!" && continue
    [ ${#NEW_NETWORK_NAME} -lt 3 ] && echoWarn "WARNING: Network name can't be shorter than 3 characters!" && continue
    [ $ARR_LEN -ne 2 ] && echoWarn "WARNING: Network name must contain single '-' character separating chain name from id!" && continue
    V1=${ARR[0]} && V2=${ARR[1]}
    [[ $V1 =~ [^a-zA-Z] ]] && echoWarn "WARNING: Network name prefix must be a word (a-z)!" && continue
    [[ $V2 != ?(-)+([0-9]) ]] && echoWarn "WARNING: Network name suffix must be a number (0-9)!" && continue
    break
done

set -x
CDHelper text lineswap --insert="NETWORK_NAME=\"$NEW_NETWORK_NAME\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="NEW_NETWORK=\"true\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
set +x

echo "INFO: Finished running network name selector"