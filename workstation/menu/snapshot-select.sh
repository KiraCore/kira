#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set +x

while : ; do
    SNAPSHOT=""
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(l|e|s)$ ]] ; do echoNErr "Recover snapshot from [L]ocal directory [E]xternal URL or [S]ync new blockchain state: " && read -d'' -s -n1 SELECT && echo -n ""; done
    
    if [ "${SELECT,,}" == "s" ] ; then
        echo "INFO: Blockchain state will NOT be recovered from the snapshot"
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
        exit 0 
    fi

    DEFAULT_SNAP_DIR=$KIRA_SNAP
    echo "INFO: Default snapshot storage directory: $DEFAULT_SNAP_DIR"
    echoNErr "Input new snapshot storage directory or press [ENTER] for default: " && read DEFAULT_SNAP_DIR && DEFAULT_SNAP_DIR="${DEFAULT_SNAP_DIR%/}"
    [ -z "$DEFAULT_SNAP_DIR" ] && DEFAULT_SNAP_DIR=$KIRA_SNAP
    if [ ! -d "$DEFAULT_SNAP_DIR" ] ; then
        echoWarn "WARNING: Directory '$DEFAULT_SNAP_DIR' does not exist!"
        continue
    else
        echoInfo "INFO: Snapshot directory will be set to '$DEFAULT_SNAP_DIR'"
        KIRA_SNAP=$DEFAULT_SNAP_DIR
    fi

    if [ "${SELECT,,}" == "e" ] ; then
        echoInfo "INFO: To find latest snapshot from the public nodes you can often use '<IP>:$DEFAULT_INTERX_PORT/download/snapshot.zip' as your URL"
        echoNErr "Input URL to download blockchain state from: " && read SNAP_URL
        set -x
        if curl -r0-0 --fail --silent "$url" >/dev/null ; then
            echo "INFO: Resource was found, attempting download"
        else
            echoErr "ERROR: It is NOT possible to access '$SNAP_URL'"
        fi
        TMP_SNAP_DIR="$KIRA_SNAP/tmp"
        TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.zip"
        rm -f -v -r $TMP_SNAP_DIR
        mkdir -p "$TMP_SNAP_DIR" "$TMP_SNAP_DIR/test"
        SUCCESS="true"
        wget "$SNAP_URL" -O $TMP_SNAP_PATH || SUCCESS="false"
        NETWORK=""
        GENSUM=""
        set +x

        if [ "${SUCCESS,,}" != "true" ] || [ ! -f "$TMP_SNAP_PATH" ] ; then
            echoErr "ERROR: Failed to download snapshot from '$SNAP_URL', resource you are trying to access might not be available or your network connection interrupted the download process"
            rm -f -v -r $TMP_SNAP_DIR
            continue
        else
            unzip $TMP_SNAP_PATH -d "$TMP_SNAP_DIR/test" || echo "INFO: Unzip failed, archive might be corruped"
            DATA_GENESIS="$TMP_SNAP_DIR/test/genesis.json"
            NETWORK=$(jq -r .chain_id $DATA_GENESIS 2> /dev/null 2> /dev/null || echo -n "")

            if [ ! -f "$DATA_GENESIS" ] || [ -z "$NETWORK"] || [ "${NETWORK,,}" == "null" ] ; then
                echoErr "ERROR: Download failed, snapshot is malformed, genesis was not found or is invalid"
                rm -f -v -r $TMP_SNAP_DIR
                continue
            else
                echoInfo "INFO: Success, snapshot was downloaded"
                GENSUM=$(sha256sum "$DATA_GENESIS" | awk '{ print $1 }' || echo -n "")
                rm -f -v -r "$TMP_SNAP_DIR/test"
            fi
        fi

        SNAPSUM=$(sha256sum "$TMP_SNAP_PATH" | awk '{ print $1 }' || echo -n "")

        echoWarn "WARNING: Snapshot checksum: '$SNAPSUM'"
        echoWarn "WARNING: Genesis file checksum: '$GENSUM'"
        OPTION="." && while ! [[ "${OPTION,,}" =~ ^(y|n)$ ]] ; do echoNErr "Is the checksum valid? (y/n): " && read -d'' -s -n1 OPTION && echo -n ""; done

        if [ "${OPTION,,}" == "n" ] ; then
            echoInfo "INFO: User rejected checksums, downloaded file will be removed"
            rm -fv $TMP_SNAP_PATH
            continue
        fi

        echoInfo "INFO: User apprived checksum, snapshot will be added to the archive directory '$KIRA_SNAP'"
        SNAP_FILENAME="${NETWORK}-latest-$(date -u +%s).zip"
        SNAPSHOT="$KIRA_SNAP/$SNAP_FILENAME"
        cp -a -v -f "$TMP_SNAP_PATH" "$SNAPSHOT"
        rm -fv $TMP_SNAP_PATH
        break
    fi

    # get all zip files in the snap directory
    SNAPSHOTS=`ls $KIRA_SNAP/*.zip` || SNAPSHOTS=""
    SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
    SNAP_LATEST_PATH="$KIRA_SNAP_PATH"
    
    if [ $SNAPSHOTS_COUNT -le 0 ] || [ -z "$SNAPSHOTS" ] ; then
      echoWarn "WARNING: No snapshots were found in the '$KIRA_SNAP' direcory, state recovery will be aborted"
      echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo -n ""
      exit 0
    fi
    
    echo -en "\e[31;1mPlease select snapshot to recover from:\e[0m" && echo -n ""
    
    i=-1
    LAST_SNAP=""
    for s in $SNAPSHOTS ; do
        i=$((i + 1))
        echo "[$i] $s"
        LAST_SNAP=$s
    done
    
    [ ! -f "$SNAP_LATEST_PATH" ] && SNAP_LATEST_PATH=$LAST_SNAP
    echo "INFO: Latest snapshot: '$SNAP_LATEST_PATH'"
    
    OPTION=""
    while : ; do
        read -p "Input snapshot number 0-$i (Default: latest): " OPTION
        [ -z "$OPTION" ] && break
        [ "${OPTION,,}" == "latest" ] && break
        [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
    done
    
    if [ ! -z "$OPTION" ] && [ "${OPTION,,}" != "latest" ] ; then
        SNAPSHOTS=( $SNAPSHOTS )
        SNAPSHOT=${SNAPSHOTS[$OPTION]}
    else
        OPTION="latest"
        SNAPSHOT=$SNAP_LATEST_PATH
    fi
    
    break
done

SNAPSUM=$(sha256sum "$SNAPSHOT" | awk '{ print $1 }' || echo -n "")
echoInfo "INFO: Snapshot '$SNAPSHOT' was selected and will be set as latest state"
echoWarn "WARNING: This is last chance to nsure following snapshot checksum is valid: $SNAPSUM"
echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo -n ""

set -x

CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KIRA_SNAP=$DEFAULT_SNAP_DIR" --prefix="KIRA_SNAP=" --path=$ETC_PROFILE --append-if-found-not=True
