#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/snap-select.sh" && rm -f $FILE && touch $FILE && nano $FILE && chmod 555 $FILE
set +x

# provide path to a file to autoconfigure snapshot
snap_file="" && arg1="$1" && [ -z "$arg1" ] && arg1="--snap-file=''"
getArgs "$arg1"


DEFAULT_INTERX_PORT="$(globGet DEFAULT_INTERX_PORT)"

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
TMP_SNAP_DIR="$KIRA_SNAP/tmp"
TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.tar"

TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)"

TRUSTED_NODE_CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)"
TRUSTED_NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
TRUSTED_NODE_SNAP_URL="$(globGet TRUSTED_NODE_SNAP_URL)"
TRUSTED_NODE_SNAP_SIZE="$(globGet TRUSTED_NODE_SNAP_SIZE)" && (! $(isNaturalNumber)) && TRUSTED_NODE_SNAP_SIZE=0

globDel OVERWRITE_SNAP_URL OVERWRITE_SNAP_SIZE

AUTOCONFIGURE_EXIT="false"

while : ; do
    # on loop continue assume fail and exit auto-configuration
    [ "$AUTOCONFIGURE_EXIT" != "false" ] && echoWarn "WARNING: Snapshot autoconfig failed" && break
    if [ -z "$snap_file" ] ; then
        set +x
        echoNC ";gre" "Download [E]xternal snapshot, select from [L]ocal direcotry or e[X]it: " && pressToContinue e l x && VSEL=$(globGet OPTION)
    else
        set -x
        AUTOCONFIGURE_EXIT="true"
        VSEL=""
    fi

    if [ "${VSEL,,}" == "x" ] ; then
        break
    elif [ "${VSEL,,}" == "e" ] ; then
        echoInfo "INFO: Please wait, snap auto-discovery..."
        TMP_SNAPS="/tmp/snaps.txt" && rm -f "$TMP_SNAPS" 
        wget $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/snap_list?ip_only=true -O $TMP_SNAPS || ( echoErr "ERROR: Snapshot discovery scan failed" && sleep 1 )
        if (! $(isFileEmpty "$TMP_SNAPS")) ; then
            echoInfo "INFO: Snapshot peer was found"
            SNAP_PEER=$(timeout 10 sed "1q;d" $TMP_SNAPS | xargs || echo "")
            AUTO_SNAP_URL="$SNAP_PEER:$DEFAULT_INTERX_PORT/download/snapshot.tar"
            AUTO_SNAP_SIZE=$(urlContentLength "$AUTO_SNAP_URL") && (! $(isNaturalNumber $AUTO_SNAP_SIZE)) && AUTO_SNAP_SIZE=0
            AUTO_STATUS=$(timeout 15 curl "$SNAP_PEER:$DEFAULT_INTERX_PORT/api/kira/status" 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
            AUTO_CHAIN_ID=$(echo "$AUTO_STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")
            if [[ $AUTO_SNAP_SIZE -gt 0 ]] && [ "$AUTO_CHAIN_ID" == "$TRUSTED_CHAIN_ID" ] ; then
                echoInfo "INFO: Snapshot auto-discovery detected $AUTO_SNAP_SIZE Bytes file '$AUTO_SNAP_URL'"
                echoWarn "WARNING: Auto-detected snapshots are NOT trusted! You are downloading them on your own risk."
            fi
        fi

        echoInfo "INFO: Default trusted node snapshot size is '$TRUSTED_NODE_SNAP_SIZE' Bytes"
        
        echoNC ";whi" "Enter URL to download snapshot or press [ENTER] for default: " && read DOWNLOAD_SNAP_URL
        [ -z "$DOWNLOAD_SNAP_URL" ] && DOWNLOAD_SNAP_URL="$TRUSTED_NODE_SNAP_URL"
        echoInfo "INFO: Please wait, testing '$DOWNLOAD_SNAP_URL' URL..."
        ($(urlExists "$DOWNLOAD_SNAP_URL")) && DOWNLOAD_SNAP_SIZE=$(urlContentLength "$DOWNLOAD_SNAP_URL") || DOWNLOAD_SNAP_SIZE=0

        if (! $(isNaturalNumber $DOWNLOAD_SNAP_SIZE)) || [[ $DOWNLOAD_SNAP_SIZE -le 0 ]] ; then
            echoErr "ERROR: Snapshot was NOT found, please provide diffrent URL next time" && continue
        fi

        echoInfo "INFO: Snapshot was found, attampting to download '$DOWNLOAD_SNAP_SIZE B' file, it might take a while..."
        rm -rfv $TMP_SNAP_DIR
        mkdir -p "$TMP_SNAP_DIR/test"
        DOWNLOAD_SUCCESS="true" && wget "$SNAP_URL" -O $TMP_SNAP_PATH || DOWNLOAD_SUCCESS="false"
        [ "$DOWNLOAD_SUCCESS" == "false" ] && echoErr "ERROR: Download failed, check if your disk space is sufficient or try again with diffrent URL" && continue

        echoInfo "INFO: File was downloaded successfully, moving file to a default snaps directory..."
        mkdir -p $KIRA_SNAP
        mv -fv $TMP_SNAP_PATH "$KIRA_SNAP/download.tar" || ( echoErr "ERROR: Failed to move snap file to snaps dir '$KIRA_SNAP' :(" && continue  )
    fi

    # get all tar files in the snap directory
    SNAPSHOTS=`ls $KIRA_SNAP/*.tar` || SNAPSHOTS=""
    SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
    SNAP_LATEST_PATH="$KIRA_SNAP_PATH"

    if [[ $SNAPSHOTS_COUNT -le 0 ]] || [ -z "$SNAPSHOTS" ] ; then
      echoErr "ERROR: Snapshots were NOT found in the snaps direcory '$KIRA_SNAP'" 
      continue
    fi

    echoC ";gre" "Select snapshot to recover from:"

    i=-1
    DEFAULT_SNAP=""
    for s in $SNAPSHOTS ; do
        i=$((i + 1))
        suffix=""
        if [ -z $DEFAULT_SNAP ] && ( [ "$SNAPSHOTS_COUNT" == "$((i + 1))" ] || ([ ! -f "$SNAP_LATEST_PATH" ] && [ "$SNAP_LATEST_PATH" == "$s"]) ) ; then
            suffix="(default)"
            DEFAULT_SNAP=$s
        fi

        echoC ";whi" " [$i] $s $suffix"
    done

    if [ ! -z "$snap_file" ] ; then
        OPTION=""
        while : ; do
            read -p ": " OPTION
            echoNC ";gre" "Input snapshot number 0-$i or press [ENTER] for default: " && read OPTION
            [ -z "$OPTION" ] && break
            ($(isNaturalNumber "$OPTION")) && [[ $OPTION -le $i ]] && break
        done

        if [ ! -z "$OPTION" ] ; then
            SNAPSHOTS=( $SNAPSHOTS )
            SELECTED_SNAPSHOT=${SNAPSHOTS[$OPTION]}
        else
            SELECTED_SNAPSHOT=$DEFAULT_SNAP
        fi
    else
        SELECTED_SNAPSHOT="$snap_file"
    fi

    cd /tmp
    mkdir -p "$TMP_SNAP_DIR/test"
    DATA_GENESIS="$TMP_SNAP_DIR/test/genesis.json" && rm -fv ./genesis.json
    SNAP_INFO="$TMP_SNAP_DIR/test/snapinfo.json" && rm -fv ./snapinfo.json
    tar -xvf $TMP_SNAP_PATH ./genesis.json || echoErr "ERROR: Exteaction issue occured, some files might be corrupted or do NOT have read permissions"
    tar -xvf $TMP_SNAP_PATH ./snapinfo.json || echoErr "ERROR: Exteaction issue occured, some files might be corrupted or do NOT have read permissions"
    mv -fv ./genesis.json $DATA_GENESIS || echo -n "" > "$DATA_GENESIS"
    mv -fv ./snapinfo.json $SNAP_INFO || echo -n "" > "$SNAP_INFO"

    SNAP_CHAIN_ID=$(jsonQuickParse "chain_id" $DATA_GENESIS 2> /dev/null || echo -n "")
    SNAP_HEIGHT=$(jsonQuickParse "height" $SNAP_INFO 2> /dev/null || echo -n "")
    SNAP_TIME=$(jsonQuickParse "time" $SNAP_INFO 2> /dev/null || echo -n "")
    (! $(isNaturalNumber "$SNAP_HEIGHT")) && SNAP_HEIGHT=0
    (! $(isNaturalNumber "$SNAP_TIME")) && SNAP_TIME=0
    
    # exit if snap file is incompatible
    [ ! -f "$DATA_GENESIS" ] && echoErr "ERROR: Data genesis not found ($DATA_GENESIS)" && continue
    [ ! -f "$SNAP_INFO" ] && echoErr "ERROR: Snap info not found ($SNAP_INFO)" && continue
    [ "$SNAP_CHAIN_ID" != "$TRUSTED_NODE_CHAIN_ID" ] && echoErr "ERROR: Expected chain id '$SNAP_CHAIN_ID' but got '$TRUSTED_NODE_CHAIN_ID'" && continue
    [[ $SNAP_HEIGHT -le 0 ]] && echoErr "ERROR: Snap height is 0" && continue

    SNAPSHOT_GENESIS_FILE="$(globFile SNAPSHOT_GENESIS)"
    echoInfo "INFO: Success, snapshot file integrity appears to be valid, saving genesis and calculating checksum..."
    cp -afv $DATA_GENESIS "$SNAPSHOT_GENESIS_FILE"
    echoInfo "INFO: Calculating snapshot genesis file checksum, be patient, this might take a while..."
    SNAPSHOT_GENESIS_HASH="$(sha256 "$SNAPSHOT_GENESIS_FILE")"

    # cleanup test directory
    rm -rfv "$TMP_SNAP_DIR/test" && mkdir -p "$TMP_SNAP_DIR"
    
    EXPECTED_FILE_NAME="$KIRA_SNAP/${SNAP_CHAIN_ID}-${SNAP_HEIGHT}-${SNAP_TIME}.tar"
    if [ "$SELECTED_SNAPSHOT" != "$EXPECTED_FILE_NAME"  ] ; then
        echoInfo "INFO: File was selected, renaming to ensure compatibility..."
        mv -fv "$SELECTED_SNAPSHOT" "$EXPECTED_FILE_NAME"
        SELECTED_SNAPSHOT="$EXPECTED_FILE_NAME"
    fi

    echoInfo "INFO: Calculating snapshot checksum, be patient, this might take a while..."
    SNAPSHOT_FILE_HASH="$(sha256 "$SELECTED_SNAPSHOT")"
    
    globSet SNAPSHOT_FILE "$SELECTED_SNAPSHOT"
    globSet SNAPSHOT_FILE_HASH "$SNAPSHOT_FILE_HASH"
    globSet SNAPSHOT_GENESIS_HASH "$SNAPSHOT_GENESIS_HASH"
    globSet SNAPSHOT_CHAIN_ID "$SNAP_CHAIN_ID"
    globSet SNAPSHOT_HEIGHT "$SNAP_HEIGHT"
    globSet SNAPSHOT_SELECTED "true"
    echoC ";gre" "Snapshot setup results:"
    echoC ";whi" "         SNAPSHOT_FILE: $(globGet SNAPSHOT_FILE)"
    echoC ";whi" "    SNAPSHOT_FILE_HASH: $(globGet SNAPSHOT_FILE_HASH)"
    echoC ";whi" " SNAPSHOT_GENESIS_HASH: $(globGet SNAPSHOT_GENESIS_HASH)"
    echoC ";whi" "     SNAPSHOT_CHAIN_ID: $(globGet SNAPSHOT_CHAIN_ID)"
    echoC ";whi" "       SNAPSHOT_HEIGHT: $(globGet SNAPSHOT_HEIGHT)"
    break
done