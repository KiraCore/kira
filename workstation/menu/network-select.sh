#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e



SELECT="" && while [ "${SELECT,,}" != "n" ] && [ ! -z "${SELECT,,}" ]; do echo -en "\e[31;1mCreate [N]ew network or press [ENTER] to continue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

NEW_NETWORK_NAME=""
if [ "${SELECT,,}" == "n" ] ; then
    while : ; do
        echo "INFO: New KIRA network will be created!"
        echo "INFO: Network name should have a format of <name>-<number>, e.g. mynetwork-1"
        echo -en "\e[31;1mProvide name of your NEW network (chain-id): \e[0m" && read NEW_NETWORK_NAME
    
        NEW_NETWORK_NAME="${NEW_NETWORK_NAME,,}"
        ARR=( $(echo "$NEW_NETWORK_NAME" | tr "-" "\n") ) && ARR_LEN=${#ARR[@]}
        [ ${#NEW_NETWORK_NAME} -gt 16 ] && echo -en "\e[33;1mWARNING: Network name can't be longer than 16 characters! \e[0m\c" && continue
        [ ${#NEW_NETWORK_NAME} -lt 3 ] && echo -en "\e[33;1mWARNING: Network name can't be shorter than 3 characters! \e[0m\c" && continue
        [ $ARR_LEN -ne 2 ] && echo -en "\e[33;1mWARNING: Network name must contain '-' character separatin name from id! \e[0m\c" && continue
        V1=${ARR[0]} && V2=${ARR[1]}
        [[ $V1 =~ [^a-zA-Z] ]] && echo "WARNING: Network name prefix must be a word (a-z)!"
        [[ $V2 != ?(-)+([0-9]) ]] && echo "WARNING: Network name suffix must be a number (0-9)!"
        break
    done
else
    SELECT="" && while [ "${SELECT,,}" != "s" ] && [ ! -z "${SELECT,,}" ]; do echo -en "\e[31;1mLaunch network from [S]napshoot or press [ENTER] to continue: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

    if [ "${SELECT,,}" == "s" ] ; then
        while : ; do
            if [ "${SELECT,,}" == "s" ] ; then
                $KIRA_MANAGER/menu/snapshoot-select.sh
        
            if [ -z "$KIRA_SNAP_PATH" ] || [ ! -f "$KIRA_SNAP_PATH" ] ; then
                echo "INFO: Snapshoot was not selected or '$KIRA_SNAP_PATH' file is not found"
            fi
        
            NEW_NETWORK_NAME=$(unzip -p $KIRA_SNAP_PATH genesis.json 2> /dev/null | jq -r '.chain_id' 2> /dev/null || echo "")

            [ -z "$NEW_NETWORK_NAME" ] && echo -en "\e[33;1mWARNING: Snapshoot file selected does not contain a genesis file, can't read the chain-id \e[0m\c" && continue
            break
        fi
    fi
fi

if [ -z "$NEW_NETWORK_NAME" ] ; then
    echo "INFO: Network name was not defined, can't continue setup process!"
    exit 1
fi

echo "INFO: Network name will be set to '$NEW_NETWORK_NAME'"
echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""

CDHelper text lineswap --insert="NETWORK_NAME=\"$NEW_NETWORK_NAME\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

