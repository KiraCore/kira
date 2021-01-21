#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
LOCAL_GENESIS_PATH="$KIRA_CONFIGS/genesis.json"

while : ; do

    rm -f "$TMP_GENESIS_PATH"
    NEW_NETWORK_NAME=""
    NEW_GENESIS_SOURCE=""

    SELECT="." && while [ "${SELECT,,}" != "n" ] && [ "${SELECT,,}" != "i" ] && [ "${SELECT,,}" != "s" ] ; do echo -en "\e[31;1mCreate [N]ew network, [I]mport genesis or use [S]napshoot: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done

    if [ "${SELECT,,}" == "n" ] ; then # create new name
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
    elif [ "${SELECT,,}" == "s" ] ; then # import from snapshoot
        $KIRA_MANAGER/menu/snapshoot-select.sh
        set +e && source "/etc/profile" &>/dev/null && set -e # make sure to get new env's
        
        if [ -z "$KIRA_SNAP_PATH" ] || [ ! -f "$KIRA_SNAP_PATH" ] ; then
            echo "INFO: Snapshoot was not selected or '$KIRA_SNAP_PATH' file was not found"
        fi

        unzip -p $KIRA_SNAP_PATH genesis.json 2> /dev/null || echo "" > "$TMP_GENESIS_PATH"
        NEW_NETWORK_NAME=$(jq .chain_id $TMP_GENESIS_PATH 2> /dev/null || echo "")
        #NEW_NETWORK_NAME=$(unzip -p $KIRA_SNAP_PATH genesis.json 2> /dev/null | jq -r '.chain_id' 2> /dev/null || echo "")
        
        [ -z "$NEW_NETWORK_NAME" ] && echo -en "\e[33;1mWARNING: Snapshoot file was not selected or does not contain a genesis file, can't read the chain-id \e[0m\c" && continue
    elif [ "${SELECT,,}" == "i" ] ; then # import from file or URL
        echo "INFO: Network genesis will be importend from the external resource"
        if [ -f "$LOCAL_GENESIS_PATH" ]; then 
            echo "INFO: Default genesis source: $LOCAL_GENESIS_PATH"
            echo -en "\e[31;1mProvide file name, URL or click [ENTER] to choose default source: \e[0m" && read NEW_GENESIS_SOURCE
        else
            echo -en "\e[31;1mProvide file name or URL to genesis source: \e[0m" && read NEW_GENESIS_SOURCE
        fi
          
        [ -z "$NEW_GENESIS_SOURCE" ] && NEW_GENESIS_SOURCE=$LOCAL_GENESIS_PATH
         
        if [ -f "$NEW_GENESIS_SOURCE" ] ; then # if NEW_GENESIS_SOURCE is a file
            echo "INFO: Attempting to copy new genesis from '$NEW_GENESIS_SOURCE'"
            cp -a -f -v $NEW_GENESIS_SOURCE $TMP_GENESIS_PATH || echo "WARNING: Failed ot copy genesis from the source file '$NEW_GENESIS_SOURCE'"
        elif [ ! -z $GENESIS_SOURCE ] ; then # if NEW_GENESIS_SOURCE is not empty
            echo "INFO: Attempting to download new genesis from '$NEW_GENESIS_SOURCE'"
            wget "$NEW_GENESIS_SOURCE" -O $TMP_GENESIS_PATH || echo "WARNING: Download failed"
        else
            echo "WARNING: Genesis source was not provided"
            continue
        fi
          
        NEW_NETWORK_NAME=$(jq .result.genesis.chain_id $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo "")
        [ ! -z "$NEW_NETWORK_NAME" ] && jq .result.genesis "$TMP_GENESIS_PATH" > "/tmp/genesis.json" && cp -a -f -v "/tmp/genesis.json" "$TMP_GENESIS_PATH"
          
        NEW_NETWORK_NAME=$(jq .chain_id $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo "")
        if [ -z "$NEW_NETWORK_NAME"] ; then
            echo "WARNING: Genesis file has invalid format, try diffrent source"
            continue
        fi
          
        echo "INFO: Success, genesis file was found and has a valid format"
        echo "INFO: $NEW_NETWORK_NAME network genesis checksum: $(sha256sum $TMP_GENESIS_PATH)"
        SELECT="." && while [ "${SELECT,,}" != "a" ] && [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "s" ] ; do echo -en "\e[31;1mChoose to [A]ccep or [R]eject the checksum: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
          
        if [ "${SELECT}" == "r" ] ; then
            echo "INFO: Genesis checksum was rejected, try diffrent source"
            continue
        fi
    else
        echo -en "\e[33;1mWARNING: Network name is not defined \e[0m\c" && echo ""
        continue
    fi

    echo "INFO: Network name will be set to '$NEW_NETWORK_NAME'"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    
    if [ -f "$TMP_GENESIS_PATH" ] ; then # if fenesis was imported then replace locally
        echo "INFO: Backing up new genesis file..."
        rm -fv "$LOCAL_GENESIS_PATH"
        cp -a -f -v $TMP_GENESIS_PATH $LOCAL_GENESIS_PATH
    fi

    CDHelper text lineswap --insert="NETWORK_NAME=\"$NEW_NETWORK_NAME\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
    break
done

