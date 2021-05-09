#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"

while :; do
    set -x
    rm -fv "$TMP_GENESIS_PATH"
    NEW_NETWORK_NAME=""
    NEW_GENESIS_SOURCE=""
    NEW_NETWORK="false"

    if [ "${INFRA_MODE,,}" == "sentry" ]; then
        set +x
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(i|s)$ ]]; do echoNErr "[I]mport genesis or use [S]napshoot: " && read -d'' -s -n1 SELECT && echo ""; done
    else
        set +x
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(n|i|s)$ ]]; do echoNErr "Create [N]ew network, [I]mport genesis or use [S]napshoot: " && read -d'' -s -n1 SELECT && echo ""; done
    fi

    set -x
    if [ "${SELECT,,}" == "n" ]; then # create new name
        $KIRA_MANAGER/menu/chain-id-select.sh
        
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        set +x
        set +e && source "/etc/profile" &>/dev/null && set -e
        set -x
        # NETWORK_NAME & NEW_NETWORK gets set my chain-id selector
        NEW_NETWORK="true"
        NEW_NETWORK_NAME=$NETWORK_NAME
    elif [ "${SELECT,,}" == "s" ] ; then # import from snapshot
        $KIRA_MANAGER/menu/snapshot-select.sh
        set +x
        set +e && source "/etc/profile" &>/dev/null && set -e # make sure to get new env's
        set -x
        NEW_NETWORK="false"
        
        if [ -z "$KIRA_SNAP_PATH" ] || [ ! -f "$KIRA_SNAP_PATH" ] ; then
            CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: Snapshot was not selected or '$KIRA_SNAP_PATH' file was not found"
            continue
        fi

        unzip -p $KIRA_SNAP_PATH genesis.json > "$TMP_GENESIS_PATH" || echo -n "" > "$TMP_GENESIS_PATH"
        NEW_NETWORK_NAME=$(jsonParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
        [ -z "$NEW_NETWORK_NAME" ] && echoWarn "WARNING: Snapshot file was not selected or does not contain a genesis file" && continue
    elif [ "${SELECT,,}" == "i" ] ; then # import from file or URL
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        echoInfo "INFO: Network genesis will be importend from the external resource"
        if [ -f "$LOCAL_GENESIS_PATH" ]; then
            LOCAL_CHAIN_ID=$(jsonParse "chain_id" $LOCAL_GENESIS_PATH 2> /dev/null || echo -n "corrupted")
            set +x
            echoInfo "INFO: Default genesis source: $LOCAL_GENESIS_PATH ($LOCAL_CHAIN_ID)"
            echoNErr "Provide file name, URL or click [ENTER] to choose default source: " && read NEW_GENESIS_SOURCE
        else
            set +x
            echoNErr "Provide file name or URL to genesis source: " && read NEW_GENESIS_SOURCE
        fi
          
        set -x
        [ -z "$NEW_GENESIS_SOURCE" ] && NEW_GENESIS_SOURCE=$LOCAL_GENESIS_PATH
         
        if [ -f "$NEW_GENESIS_SOURCE" ] ; then # if NEW_GENESIS_SOURCE is a file
            echoInfo "INFO: Attempting to copy new genesis from '$NEW_GENESIS_SOURCE'"
            cp -a -f -v $NEW_GENESIS_SOURCE $TMP_GENESIS_PATH || echo "WARNING: Failed ot copy genesis from the source file '$NEW_GENESIS_SOURCE'"
        elif [ ! -z $NEW_GENESIS_SOURCE ] ; then # if NEW_GENESIS_SOURCE is not empty
            echoInfo "INFO: Attempting to download new genesis from '$NEW_GENESIS_SOURCE'"
            rm -fv $TMP_GENESIS_PATH
            DNPASS="true" && wget "$NEW_GENESIS_SOURCE" -O $TMP_GENESIS_PATH || DNPASS="false"
            GENTEST=$(jsonParse "result.genesis.chain_id" $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo -n "")
            ( [ -z "$GENTEST" ] || [ "${GENTEST,,}" == "null" ] ) && GENTEST=$(jsonParse "result.genesis.chain_id" $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo -n "")
            if [ "${DNPASS,,}" == "false" ] || [ -z "$GENTEST" ] ; then
                echoWarn "WARNING: Download failed, attempting second discovery..."
                rm -fv "$TMP_GENESIS_PATH" 
                wget "$NEW_GENESIS_SOURCE:$DEFAULT_INTERX_PORT/download/genesis.json" -O $TMP_GENESIS_PATH || echo "WARNING: Second download failed"
            fi
        else
            echoWarn "WARNING: Genesis source was not provided"
            continue
        fi

        NEW_NETWORK_NAME=$(jsonParse "result.genesis.chain_id" $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo -n "")
        if [ ! -z "$NEW_NETWORK_NAME" ] && [ "$NEW_NETWORK_NAME" != "null" ] ; then
            jsonParse "result.genesis" "$TMP_GENESIS_PATH" > "/tmp/genesis.buffer.json"
            cp -a -f -v "/tmp/genesis.buffer.json" "$TMP_GENESIS_PATH"
        else
            NEW_NETWORK_NAME=$(jsonParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null 2> /dev/null || echo -n "")
        fi

        if [ -z "$NEW_NETWORK_NAME" ] || [ "${NEW_NETWORK_NAME,,}" == "null" ] ; then
            echoWarn "WARNING: Genesis file has invalid format, try diffrent source"
            continue
        fi
          
        set +x
        echoInfo "INFO: Success, genesis file was found and has a valid format"
        echoInfo "INFO: $NEW_NETWORK_NAME network genesis checksum: $(sha256 $TMP_GENESIS_PATH)"
        SELECT="." && while [ "${SELECT,,}" != "a" ] && [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "s" ] ; do echoNErr "Choose to [A]ccep or [R]eject the checksum: " && read -d'' -s -n1 SELECT && echo ""; done
        set -x

        if [ "${SELECT}" == "r" ] ; then
            echoInfo "INFO: Genesis checksum was rejected, try diffrent source"
            continue
        fi
    else
        echoWarn -en "WARNING: Network name is not defined"
        continue
    fi

    set +x
    echoInfo "INFO: Network name will be set to '$NEW_NETWORK_NAME'"
    echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
    set -x
    
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
    rm -fv "$LOCAL_GENESIS_PATH"
    if [ -f "$TMP_GENESIS_PATH" ] ; then # if genesis was imported then replace locally
        echoInfo "INFO: Backing up new genesis file..."
        cp -afv $TMP_GENESIS_PATH $LOCAL_GENESIS_PATH
        rm -fv "$TMP_GENESIS_PATH"
    fi

    CDHelper text lineswap --insert="NETWORK_NAME=\"$NEW_NETWORK_NAME\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="NEW_NETWORK=\"$NEW_NETWORK\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
    # if new network was created then we can delete public seeds from configuration
    [ "${NEW_NETWORK,,}" == "true" ] && rm -fv "$KIRA_CONFIGS/public_seeds"
    break
done

# Make sure genesis already exists if joining exisitng network was initiated
if [ "${NEW_NETWORK,,}" == "false" ] && [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
    echoErr "ERROR: Genesis file is missing despite attempt to join existing network"
    exit 1
fi

if [ "${INFRA_MODE,,}" == "validator" ] && [ "${NEW_NETWORK}" == "false" ] ; then
    set +x
    echoInfo "INFO: Validator mode detected, last parameter to setup..."
    echoErr "IMORTANT: To prevent validator from double signing you MUST define a minimum block height below which new blocks will NOT be produced!"
    echoWarn "IMORTANT: Set minimum block height to the latest block height that the network reached. If you input 0 and do NOT set this parameter to the latest height then the block height will be auto detected from the node you are currently connecting to, HOWEVER auto detection of the block height can't be 100% trused (because node might be behind latest block height) and in production environment a spacial care should be taken while setting this property!"
    
    while : ; do
        echoNErr "Define minimum block height: " && read MIN_HEIGHT
        (! $(isNaturalNumber $MIN_HEIGHT)) && continue
        break
    done

    echoInfo "INFO: Minimum block height your validator node will start prodicing new blocks at will be no lower than $MIN_HEIGHT"
    globSet MIN_HEIGHT $MIN_HEIGHT
    echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
    set -x
else
    globSet MIN_HEIGHT 0
fi

