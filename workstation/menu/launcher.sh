#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/launcher.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

systemctl stop kirascan || echoWarn "WARNING: KIRA scan service could NOT be stopped"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service could NOT be stopped"
systemctl stop kiraplan || echoWarn "WARNING: KIRA upgrade service could NOT be stopped"
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
sleep 1

timedatectl set-timezone "Etc/UTC" || ( echoErr "ERROR: Failed to set time zone to UTC, ensure to do that manually after setup is finalized!" && sleep 10 )

MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS

while :; do
    set -x
    $KIRA_MANAGER/menu/seed-status-refresh.sh

    IFACE=$(globGet IFACE)
    INFRA_MODE=$(globGet INFRA_MODE)
    CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)" 
    HEIGHT="$(globGet TRUSTED_NODE_HEIGHT)"
    NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
    NEW_NETWORK="$(globGet NEW_NETWORK)"
    [ -z "$CHAIN_ID" ] && CHAIN_ID="???"

    TRUSTED_NODE_GENESIS_HASH="$(globGet TRUSTED_NODE_GENESIS_HASH)"
    TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
    TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)"
    TRUSTED_NODE_SNAP_URL="$(globGet TRUSTED_NODE_SNAP_URL)"
    TRUSTED_NODE_SNAP_SIZE="$(globGet TRUSTED_NODE_SNAP_SIZE)"
    (! $(isNaturalNumber)) && TRUSTED_NODE_SNAP_SIZE=0

    SNAPSHOT_FILE=$(globGet SNAPSHOT_FILE)
    SNAPSHOT_FILE_HASH=$(globGet SNAPSHOT_FILE_HASH)
    SNAPSHOT_GENESIS_HASH=$(globGet SNAPSHOT_GENESIS_HASH)

    if [ -z "$SNAPSHOT_CHAIN_ID" ] || [ "$SNAPSHOT_CHAIN_ID" != "$CHAIN_ID" ] || [ ! -f "$SNAPSHOT_FILE"] ; then
      SNAPSHOT_VALID="false"
    else
      SNAPSHOT_VALID="true"
    fi

    [ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"
    if (! $(isDnsOrIp "$NODE_ADDR")) ; then
      NODE_ADDR="???.???.???.???"
      CHAIN_ID="???"
      HEIGHT="0"
    elif [ "$NODE_ADDR" != "0.0.0.0" ] ; then
      ($(isPort "$TRUSTED_NODE_INTERX_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_INTERX_PORT}" || \
       ( ($(isPort "$TRUSTED_NODE_RPC_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_RPC_PORT}" )
    fi

    echoInfo "INFO: Public & Local IP discovery..."
    PUBLIC_IP=$(timeout 10 bash -c ". /etc/profile && getPublicIp" 2> /dev/null || echo "")
    LOCAL_IP=$(timeout 10 bash -c ". /etc/profile && getLocalIp '$IFACE'" 2> /dev/null || echo "")
    (! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP="???.???.???.???"
    (! $(isDnsOrIp "$LOCAL_IP")) && LOCAL_IP="???.???.???.???"
    
    set +x
    MASTER_MNEMONIC="$(tryGetVar MASTER_MNEMONIC "$MNEMONICS")"
    ($(isMnemonic "$MASTER_MNEMONIC")) && MNEMONIC_SAVED="true" || MNEMONIC_SAVED="false"
    MASTER_MNEMONIC=""
    set -x
    NODE_ID=$(tryGetVar "$(toUpper "$INFRA_MODE")_NODE_ID" "$MNEMONICS")
    (! $(isNodeId "$NODE_ID")) && NODE_ID="???...???"

    SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 11)
    P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 12)
    RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 12)
    GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 12)
    PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 12)
    INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 14)
    EXPOSURE="local network exposure" 
    SNAPS="snapshots disabled" 
    LMODE="join '$CHAIN_ID' network" 
    [ "$(globGet PRIVATE_MODE)" == "false" ] && EXPOSURE="public network exposure"
    [ "$(globGet SNAPSHOT_EXECUTE)" == "true" ] && SNAPS="snapshots enabled"
    [ "$NEW_NETWORK" == "true" ] && LMODE="create new test network"

    SNAP_URL=$(globGet TRUSTED_SNAP_URL)
    SNAP_SIZE=$(globGet TRUSTED_SNAP_SIZE)

    DOCKER_SUBNET="$(globGet KIRA_DOCKER_SUBNET)"
    DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"

    FIREWALL_ENABLED="$(globGet FIREWALL_ENABLED)"

    set +x && printf "\033c" && clear && setterm -cursor off
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "$(toUpper $INFRA_MODE) NODE LAUNCHER, KM $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  SSH PORT |  P2P PORT  |  RPC PORT  |  GRPC PORT | PROMETHEUS | INTERX (API) |"
    echoC ";whi" "|$SSH_PORT|$P2P_PORT|$RPC_PORT|$GRPC_PORT|$PRTH_PORT|$INEX_PORT|"
    if [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ; then
  echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " NETWORK NOT FOUND, CHANGE TRUSTED SEED ADDRESS " 78 "." "-")")|"
    elif [ "$NEW_NETWORK" != "true" ] && (! $(isSHA256 "$TRUSTED_NODE_GENESIS_HASH")) ; then
  echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " GENESIS FILE NOT FOUND, CHANGE TRUSTED SEED OR PROVIDE SOURCE " 78 "." "-")")|"
    elif [ "$MNEMONIC_SAVED" == "false" ] ; then
echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " MASTER MNEMONIC IS NOT DEFINED " 78 "." "-")")|"
    elif [ "$FIREWALL_ENABLED" == "false" ] ; then
  echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " FIREWALL DISABLED " 78 "." "-")")|"
    else
  echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    fi
  
    (! $(isNodeId "$NODE_ID")) && col="red" || col="whi"
 echoC "sto;whi" "|$(echoC "res;$col" " $(strFixR "${INFRA_MODE^} Node ID" 19): $(strFixL "$NODE_ID" 55) ")|" 
 [ "$NEW_NETWORK" != "true" ] && ($(isSHA256 "$TRUSTED_NODE_GENESIS_HASH")) && \
    echoC ";whi" "|        Genesis Hash: $(strFixL "$TRUSTED_NODE_GENESIS_HASH" 55) |"
 
    echoC ";whi" "|   Secrets Direcotry: $(strFixL "$KIRA_SECRETS" 55) |"

    if [ "$SNAPSHOT_VALID" == "true" ] ; then
      echoC ";whi" "| Snapshots Direcotry: $(strFixL "$KIRA_SNAP" 55) |"
      echoC ";whi" "|      Snapshots File: $(strFixL "$SNAPSHOT_FILE - $(prettyBytes "$(fileSize "$SNAPSHOT_FILE")")" 40) $(strFixR "$(prettyBytes "$(fileSize "$SNAPSHOT_FILE")")" 14) |"
      echoC ";whi" "|  Snapshots Checksum: $(strFixL "$SNAPSHOT_FILE_HASH" 55) |"
      echoC ";whi" "|  Snap. Genesis Hash: $(strFixL "$SNAPSHOT_GENESIS_HASH" 55) |"
    fi
    [ "$NEW_NETWORK" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echoC ";whi" "|      Local Snapshot: $(strFixL "$KIRA_SNAP_PATH" 55) |"
    [ "$NEW_NETWORK" != "true" ] && [[ $SNAP_SIZE -gt 0 ]] && \
    echoC ";whi" "|   External Snapshot: $(strFixL "$SNAP_URL" 55) |"
    echoC ";whi" "|   Base Image Source: $(strFixL "$(globGet NEW_BASE_IMAGE_SRC)" 55) |"
    echoC ";whi" "|  KIRA Manger Source: $(strFixL "$(globGet INFRA_SRC)" 55) |"
    echoC "sto;whi" "|$(echoC "res;bla" "----------- SELECT OPTION -----------:------------- CURRENT VALUE ------------")|"

    [ "$MNEMONIC_SAVED" == "true" ] && \
                       echoC ";whi" "| [1] | Modify Master Mnemonic        : $(strFixL "" 39)|" ||
    echoC ";whi" "| $(echoC "res;red" "[1] | Set or Gen. Master Mnemonic   : $(strFixL "" 39)")|"
    echoC ";whi" "| [2] | Modify Networking Config.     : $(strFixL "$IFACE, $DOCKER_NETWORK, $DOCKER_SUBNET" 39)|"
    echoC ";whi" "| [3] | Switch to Diffrent Node Type  : $(strFixL "$INFRA_MODE node" 39)|"
    [ "$(globGet PRIVATE_MODE)" == "true" ] && \
    echoC ";whi" "| [4] | Expose Node to Public Netw.   : $(strFixL "expose as $LOCAL_IP to LOCAL" 39)|" || \
    echoC ";whi" "| [4] | Expose Node to Local Networks : $(strFixL "expose as $PUBLIC_IP to PUBLIC" 39)|"

    echoC ";whi" "| [5] | Download or Select Snapshot   : $(strFixL "$SNAPS" 39)|"
    if [ "$INFRA_MODE" == "validator" ] ; then
    [ "$NEW_NETWORK" == "true" ] && \
    echoC ";whi" "| [6] | Join Existing Network         : $(strFixL "launch your own testnet" 39)|" || \
    echoC ";whi" "| [6] | Launch New Local Testnet      : $(strFixL "join existing public or test network" 39)|"
    fi
    [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] && col="red" || col="whi"
    [ "$NEW_NETWORK" == "true" ] && \
                        echoC ";whi" "| [7] | Modify Network Name           : $(strFixL "$(globGet NEW_NETWORK_NAME)" 39)|" || \
 echoC "sto;whi" "| $(echoC "res;$col" "[7] | Modify Trusted Node Address   : $(strFixL "$NODE_ADDR" 39)")|"
 
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    ( ( [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ) || [ "$MNEMONIC_SAVED" == "false" ] ) && \
    col="bla" || col="gre"

  echoC "sto;whi" "| $(echoC "res;$col" "$(strFixL "[S] | Start Setup, height: $HEIGHT" 36)")| [R] Refresh      | [X] Abort Setup     |"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    
    if ( ( [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ) || [ "$MNEMONIC_SAVED" == "false" ] ) ; then
        pressToContinue 1 2 3 4 5 6 7 8 r x && KEY=$(globGet OPTION)
    else
        pressToContinue 1 2 3 4 5 6 7 8 s r x && KEY=$(globGet OPTION)
    fi
    setterm -cursor on

  case ${KEY,,} in
  s*)
    echo "INFO: Starting Quick Setup..."
    setGlobEnv KIRA_SNAP_PATH ""
    globSet BASE_IMAGE_SRC "$(globGet NEW_BASE_IMAGE_SRC)"
    $KIRA_MANAGER/menu/quick-select.sh
    break
    ;;
  1*)
    $KIRA_MANAGER/menu/mnemonic-select.sh
    ;;
  2*)
    $KIRA_MANAGER/menu/ports-select.sh
    ;;
  3*)
    $KIRA_MANAGER/menu/node-type-select.sh
    ;;
  4*)
    [ "$PRIVATE_MODE" == "true" ] && globSet PRIVATE_MODE "false" || globSet PRIVATE_MODE "true"
    ;;
  5*)
    $KIRA_MANAGER/menu/snap-select.sh
    ;;
  6*)
    [ "$INFRA_MODE" != "validator" ] && continue
    if [ "$NEW_NETWORK" == "true" ] ; then
      globSet NEW_NETWORK "false" 
    else
      globSet NEW_NETWORK "true"
      globSet NEW_NETWORK_NAME "localnet-$((RANDOM % 999 + 1))"
    fi
   ;;
   7*)
      if [ "$(globGet NEW_NETWORK)" == "true" ] ; then
        $KIRA_MANAGER/menu/chain-id-select.sh
      else
        $KIRA_MANAGER/menu/trusted-node-select.sh
      fi
   ;;
  x*)
    exit 0
    ;;
  r*)
    continue
    ;;
  *)
    echo "Try again."
    sleep 1
    ;;
  esac
done
set -x

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

exit 0
