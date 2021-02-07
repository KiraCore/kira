#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

while : ; do
    SNAPSHOOT=""
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(l|e|s)$ ]] ; do echoNErr "Recover snapshoot from [L]ocal directory [E]xternal URL or [S]ync new blockchain state: " && read -d'' -s -n1 SELECT && echo ""; done
    
    if [ "${SELECT,,}" == "s" ] ; then
        echo "INFO: Blockchain state will NOT be recovered from the snapshoot"
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        exit 0 
    fi

    DEFAULT_SNAP_DIR=$KIRA_SNAP
    echo "INFO: Default snapshoot storage directory: $DEFAULT_SNAP_DIR"
    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(k|c)$ ]] ; do echoNErr "[K]eep default snapshoot storage directory or [C]hange: " && read -d'' -s -n1 OPTION && echo ""; done
    
    [ "${OPTION,,}" == "c" ] && read "$DEFAULT_SNAP_DIR" && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}" # read and trim leading slash
    [ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
    echoInfo "INFO: Snapshoot directory will be set to '$DEFAULT_SNAP_DIR'"
    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|t)$ ]] ; do echoNErr "Choose to [A]ccept directory or [T]ry again: " && read -d'' -s -n1 OPTION && echo "" ; done
    [ "${OPTION,,}" == "t" ] && continue
    
    if [ "$KIRA_SNAP" != "$DEFAULT_SNAP_DIR" ] ; then
        CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
        KIRA_SNAP=$DEFAULT_SNAP_DIR
    fi

    if [ "${SELECT,,}" == "e" ] ; then
        echo "INFO: To find latest snapshoot from the public nodes you can often use '<IP>:$KIRA_INTEREX_PORT/downloads/snapshoot.zip' as your URL"
        echoNErr "Input URL to download blockchain state from: " && read SNAP_URL
        if curl --head --fail --silent "$url" >/dev/null ; then
            echo "INFO: Resource was found, attempting download"
        else
            echoErr "ERROR: Failue, it is NOT possible to access '$SNAP_URL'"
        fi
        TMP_SNAP_DIR="$DEFAULT_SNAP_DIR/tmp"
        TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.zip"
        rm -f -v -r $TMP_SNAP_DIR
        mkdir -p "$TMP_SNAP_DIR" "$TMP_SNAP_PATH/test"
        SUCCESS="true"
        wget "$SNAP_URL" -O $TMP_SNAP_PATH || SUCCESS="false"
        NETWORK=""
        GENSUM=""

        if [ "${SUCCESS,,}" != "true" ] || [ ! -f "$TMP_SNAP_PATH" ] ; then
            echoErr "ERROR: Failed to download snapshoot from '$SNAP_URL', resource you are trying to access might not be available or your network connection interrupted the download process"
            rm -f -v -r $TMP_SNAP_DIR
            continue
        else
            unzip $TMP_SNAP_PATH -d "$TMP_SNAP_DIR/test" || echo "INFO: Unzip failed, archive might be corruped"
            DATA_GENESIS="$TMP_SNAP_DIR/test/genesis.json"
            NETWORK=$(jq -r .chain_id $DATA_GENESIS 2> /dev/null 2> /dev/null || echo "")

            if [ ! -f "$DATA_GENESIS" ] || [ -z "$NETWORK"] || [ "${NETWORK,,}" == "null" ] ; then
                echoErr "ERROR: Download failed, snapshoot is malformed, genesis was not found or is invalid"
                rm -f -v -r $TMP_SNAP_DIR
                continue
            else
                echoInfo "INFO: Success, snapshoot was downloaded"
                GENSUM=$(sha256sum "$DATA_GENESIS" | awk '{ print $1 }' || echo "")
                rm -f -v -r "$TMP_SNAP_DIR/test"
            fi
        fi

        SNAPSUM=$(sha256sum "$TMP_SNAP_PATH" | awk '{ print $1 }' || echo "")

        echoWarn "WARNING: Snapshoot checksum: '$SNAPSUM'"
        echoWarn "WARNING: Genesis file checksum: '$GENSUM'"
        OPTION="." && while ! [[ "${OPTION,,}" =~ ^(y|n)$ ]] ; do echoNErr "Is the checksum valid? (y/n): " && read -d'' -s -n1 OPTION && echo ""; done

        if [ "${OPTION,,}" == "n" ] ; then
            echoInfo "INFO: User rejected checksums, downloaded file will be removed"
            rm -fv $TMP_SNAP_PATH
            continue
        fi

        echoInfo "INFO: User apprived checksum, snapshoot will be added to the archive directory '$KIRA_SNAP'"
        SNAP_FILENAME="${NETWORK}-latest-$(date -u +%s).zip"
        SNAPSHOOT="$KIRA_SNAP/$SNAP_FILENAME"
        cp -a -v -f "$TMP_SNAP_PATH" "$SNAPSHOOT"
        rm -fv $TMP_SNAP_PATH
        break
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
    
    break
done

SNAPSUM=$(sha256sum "$SNAPSHOOT" | awk '{ print $1 }' || echo "")
echoInfo "INFO: Snapshoot '$SNAPSHOOT' was selected and will be set as latest state"
echoWarn "WARNING: This is last chance to nsure following snapshoot checksum is valid: $SNAPSUM"
echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""

set -x

CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

