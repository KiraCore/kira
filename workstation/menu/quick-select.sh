#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/quick-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

mkdir -p "$KIRA_CONFIGS"

NEW_NETWORK="$(globGet NEW_NETWORK)"
SNAPSHOT_FILE=$(globGet SNAPSHOT_FILE)
SNAPSHOT_GENESIS_FILE=$(globFile SNAPSHOT_GENESIS_FILE)
SNAPSHOT_HEIGHT=$(globGet SNAPSHOT_HEIGHT)
(! $(isNaturalNumber "$SNAPSHOT_HEIGHT")) && SNAPSHOT_HEIGHT=0

TRUSTED_NODE_HEIGHT="$(globGet TRUSTED_NODE_HEIGHT)"
TRUSTED_NODE_CHAIN_ID=$(globGet TRUSTED_NODE_CHAIN_ID)
TRUSTED_NODE_GENESIS_FILE=$(globFile TRUSTED_NODE_GENESIS_FILE)
TRUSTED_NODE_GENESIS_HASH="$(globGet TRUSTED_NODE_GENESIS_HASH)"
(! $(isNaturalNumber "$TRUSTED_NODE_HEIGHT")) && TRUSTED_NODE_HEIGHT=0

SEEDS_COUNT=$(wc -l < $PUBLIC_SEEDS || echo "0")
(! $(isNaturalNumber "$SEEDS_COUNT")) && SEEDS_COUNT=0

[ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"

echoInfo "INFO: Staring initial cleanup..."

# cleanup common directory and old files
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
rm -rfv "$DOCKER_COMMON" "$DOCKER_COMMON_RO" "$GLOBAL_COMMON_RO" "$LOCAL_GENESIS_PATH"
mkdir -p "$DOCKER_COMMON" "$DOCKER_COMMON_RO" "$GLOBAL_COMMON_RO"

if [ -f $SNAPSHOT_FILE ] ; then
    find $KIRA_SNAP -not -name "$(basename $SNAPSHOT_FILE)" -delete || echoWarn "WARNINIG: Failed to delete unused snaps"
else
    rm -fv $KIRA_SNAP/*.tar || echoErr "ERROR: Failed to wipe *.tar files from '$KIRA_SNAP' directory"
fi

rm -fv $KIRA_SNAP/*.zip || echoErr "ERROR: Failed to wipe *.zip files from '$KIRA_SNAP' directory"
rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"
rm -fv $DOCKER_COMMON_RO/snap.* || echoErr "ERROR: Failed to wipe snap.* files from '$DOCKER_COMMON_RO' directory"
rm -fvr "$KIRA_SNAP/status"

BLOCK_TIME="0"
MIN_HEIGHT="0"
KIRA_SNAP_PATH=""
KIRA_SNAP_SHA256=""
if [ "$NEW_NETWORK" != "true" ] ; then
    if [ "$SNAPSHOT_CORRUPTED" != "true" ] && [ "$SNAPSHOT_SYNC" == "true" ] ; then
        echoInfo  "INFO: Snapshot will be used to speed up node sync"
        cp -vaf "$SNAPSHOT_GENESIS_FILE" "$LOCAL_GENESIS_PATH"
        KIRA_SNAP_PATH="$(globGet SNAPSHOT_FILE)"
        KIRA_SNAP_SHA256="$(globGet SNAPSHOT_FILE_HASH)"
        MIN_HEIGHT="$SNAPSHOT_HEIGHT"
    else
        echoInfo  "INFO: Node will sync without snapshot."
        cp -vaf "$TRUSTED_NODE_GENESIS_FILE" "$LOCAL_GENESIS_PATH"
    fi

    [[ $TRUSTED_NODE_HEIGHT -gt $MIN_HEIGHT ]] && MIN_HEIGHT=$TRUSTED_NODE_HEIGHT
    BLOCK_TIME=$(jsonParse "genesis_time" $TRUSTED_NODE_GENESIS_FILE 2> /dev/null || echo -n "")
else
    echoInfo  "INFO: new network will be created during node setup process."
fi

# Make sure genesis already exists if joining exisitng network was initiated
if [ "$NEW_NETWORK" != "true" ] ; then 
    if [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
        echoErr "ERROR: Genesis file is missing despite attempt to join existing network"
        exit 1
    fi

    if [ "$REINITALIZE_NODE" == "false" ] && [ $SEEDS_COUNT -le 0 ] ; then
        echoErr "ERROR: No P2P seed nodes were found, choose diffrent trusted peer!"
        exit 1
    fi
fi

echoInfo "INFO: Configuring essential startup variables..."
setGlobEnv NETWORK_NAME "$TRUSTED_NODE_CHAIN_ID"
setGlobEnv KIRA_SNAP_PATH "$KIRA_SNAP_PATH"
setGlobEnv KIRA_SNAP_SHA256 "$KIRA_SNAP_SHA256"

globSet BASE_IMAGE_SRC "$(globGet NEW_BASE_IMAGE_SRC)"
globSet GENESIS_SHA256 "$TRUSTED_NODE_GENESIS_HASH"

globSet MIN_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
globSet LATEST_BLOCK_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
globSet LATEST_BLOCK_TIME "$(date2unix $BLOCK_TIME)" $GLOBAL_COMMON_RO

echoInfo "INFO: Wiping old node state..."
touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"

globDel "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "CONTAINERS_UPDATED_$KIRA_SETUP_VER" UPGRADE_PLAN
globDel VALIDATOR_ADDR UPDATE_FAIL_COUNTER SETUP_END_DT UPDATE_CONTAINERS_LOG UPDATE_CLEANUP_LOG UPDATE_TOOLS_LOG LATEST_STATUS SNAPSHOT_TARGET

# disable snapshots & cleanup space
globSet SNAP_EXPOSE "false"
globSet SNAPSHOT_EXECUTE "false"
globSet SNAPSHOT_UNHALT "true"
globSet SNAPSHOT_KEEP_OLD "false"

globSet UPDATE_DONE "false"
globSet UPDATE_FAIL "false"
globSet SYSTEM_REBOOT "false"

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
globSet SETUP_START_DT "$SETUP_START_DT"
globSet PORTS_EXPOSURE "enabled"

globDel "sentry_SEKAID_STATUS" "validator_SEKAID_STATUS" "seed_SEKAID_STATUS" "interx_SEKAID_STATUS"
rm -fv "$(globFile validator_SEKAID_STATUS)" "$(globFile sentry_SEKAID_STATUS)" "$(globFile seed_SEKAID_STATUS)" "$(globFile interx_SEKAID_STATUS)"

globDel UPGRADE_INSTATE
globSet UPGRADE_DONE "true"
globSet UPGRADE_TIME "$(date2unix $(date))"
globSet AUTO_UPGRADES "true"
globSet PLAN_DONE "true"
globSet PLAN_FAIL "false"
globSet PLAN_FAIL_COUNT "0"
globSet PLAN_START_DT "$(date +'%Y-%m-%d %H:%M:%S')"
globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"

mkdir -p $KIRA_LOGS
echo -n "" > $KIRA_LOGS/kiraup.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraup.log'"
echo -n "" > $KIRA_LOGS/kiraplan.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraplan.log'"

$KIRA_MANAGER/setup/services.sh
systemctl daemon-reload
systemctl enable kiraup
systemctl enable kiraplan
systemctl start kiraup
systemctl stop kiraplan || echoWarn "WARNING: Failed to stop KIRA Plan!"
systemctl restart systemd-journald

echoInfo "INFO: Starting install logs preview, to exit type Ctrl+c"
sleep 2

if [ "$(isServiceActive kiraup)" == "true" ] ; then
  cat $KIRA_LOGS/kiraup.log
else
  systemctl status kiraup
  echoErr "ERROR: Failed to launch kiraup service!"
  exit 1
fi

$KIRA_MANAGER/kira/kira.sh