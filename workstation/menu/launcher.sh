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
set +x
source $MNEMONICS

while (! $(isMnemonic "$MASTER_MNEMONIC")) ; do
    echoInfo "INFO: Private key store location: '$MNEMONICS'"
    echoWarn "WARNING: Master mnemonic is invalid or was NOT found within the key store"
    echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read MASTER_MNEMONIC
    MASTER_MNEMONIC=$(echo "$MASTER_MNEMONIC" | xargs 2> /dev/null || echo -n "")
    MASTER_MNEMONIC=$(echo ${MASTER_MNEMONIC//,/ })

    if [ -z "$MASTER_MNEMONIC" ] ; then
      echoInfo "INFO: Master mnemonic will be auto-generated during setup"
      MASTER_MNEMONIC="autogen"
    elif ($(isMnemonic "$MASTER_MNEMONIC")) ; then
      echoInfo "INFO: Master mnemonic is valid and will be saved to keystore"
    else
      echoErr "ERROR: Invalid Bip39 seed words sequence"
      continue
    fi

    setVar MASTER_MNEMONIC "$MASTER_MNEMONIC" "$MNEMONICS" 1> /dev/null
    break
done

echo "INFO: Loading secrets..."
set +e
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

while :; do

    $KIRA_MANAGER/menu/seed-status-refresh.sh

    CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)" && [ -z "$CHAIN_ID" ] && CHAIN_ID="???"
    HEIGHT="$(globGet TRUSTED_NODE_HEIGHT)"
    NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
    NEW_NETWORK=$(globGet NEW_NETWORK)
    [ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"
    if (! $(isDnsOrIp "$NODE_ADDR")) ; then
      NODE_ADDR="???.???.???.???"
      CHAIN_ID="???"
      HEIGHT="0"
    fi
    
    set +x
    source $MNEMONICS
    
    printf "\033c"

    SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 11)
    P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 11)
    RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 11)
    GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 12)
    PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 14)
    INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 14)
    EXPOSURE="local networks" && [ "$(globGet PRIVATE_MODE)" == "false" ] && EXPOSURE="public networks"
    SNAPS="snap disabled" && [ "$(globGet SNAPSHOT_EXECUTE)" == "true" ] && SNAPS="snap enabled"
    LMODE="join '$CHAIN_ID' network" && [ "$NEW_NETWORK" == "true" ] && LMODE="create new test network"

    SNAP_URL=$(globGet TRUSTED_SNAP_URL)
    SNAP_SIZE=$(globGet TRUSTED_SNAP_SIZE)

    DOCKER_SUBNET="$(globGet KIRA_DOCKER_SUBNET)"
    DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"
    
    FIREWALL_ENABLED="$(globGet FIREWALL_ENABLED)"

    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "$(toUpper $(globGet INFRA_MODE)) NODE LAUNCHER, KM $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "| SSH PORT  | P2P PORT  | RPC PORT  | GRPC PORT  |  PROMETHEUS  | INTERX (API) |"
    echoC ";whi" "|$SSH_PORT|$P2P_PORT|$RPC_PORT|$GRPC_PORT|$PRTH_PORT|$INEX_PORT|"
    if [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ; then
  echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " NETWORK NOT FOUND, CHANGE TRUSTED SEED ADDRESS " 78 "." "-")")|"
    else
    [ "$FIREWALL_ENABLED" == "false" ] && \
  echoC "sto;whi" "|$(echoC "res;red" "$(strFixC " FIREWALL DISABLED " 78 "." "-")")|" || \
  echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    fi
    #[ "$NEW_NETWORK" == "false" ] && \
    #echoC ";whi" "|        Network Name: $(strFixL "$CHAIN_ID" 55) |"
    echoC ";whi" "|   Secrets Direcotry: $(strFixL "$KIRA_SECRETS" 55) |"
    echoC ";whi" "| Snapshots Direcotry: $(strFixL "$KIRA_SNAP" 55) |"
    [ "$NEW_NETWORK" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echoC ";whi" "|      Local Snapshot: $(strFixL "$KIRA_SNAP_PATH" 55) |"
    [ "$NEW_NETWORK" != "true" ] && [[ $SNAP_SIZE -gt 0 ]] && \
    echoC ";whi" "|   External Snapshot: $(strFixL "$SNAP_URL" 55) |"
    echoC ";whi" "|   Base Image Source: $(strFixL "$(globGet NEW_BASE_IMAGE_SRC)" 55) |"
    echoC ";whi" "|  KIRA Manger Source: $(strFixL "$(globGet INFRA_SRC)" 55) |"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC ";whi" "| [1] | Change Master Mnemonic        : $(strFixL "" 39)|"
    echoC ";whi" "| [2] | Change Networking Config.     : $(strFixL "$(globGet IFACE) : $DOCKER_NETWORK : $DOCKER_SUBNET" 39)|"
    echoC ";whi" "| [3] | Change Base Image URL         : $(strFixL "" 39)|"
    echoC ";whi" "| [4] | Change Node Type              : $(strFixL "$(globGet INFRA_MODE)" 39)|"
    echoC ";whi" "| [5] | Change Network Exposure       : $(strFixL "$EXPOSURE" 39)|"
    echoC ";whi" "| [6] | Change Snapshots Config.      : $(strFixL "$SNAPS" 39)|"
    echoC ";whi" "| [7] | Change Network Launch Mode    : $(strFixL "$LMODE" 39)|"
    [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] && col="red" || col="whi"
    [ "$NEW_NETWORK" == "true" ] && \
                        echoC ";whi" "| [8] | Change Network Name           : $(strFixL "$(globGet NEW_NETWORK_NAME)" 39)|" || \
 echoC "sto;whi" "| $(echoC "res;$col" "[8] | Change Trusted Node Address   : $(strFixL "$NODE_ADDR" 39)")|"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    [ "$NEW_NETWORK" == "false" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] && col="bla" || col="gre"
  echoC "sto;whi" "| $(echoC "res;$col" "[S] | Start Setup")                   | [R] Refresh      | [X] Abort Setup     |"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    setterm -cursor off
    if [ "$NEW_NETWORK" != "true" ] && [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ; then
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
    continue
    ;;
  2*)
    $KIRA_MANAGER/menu/ports-select.sh
    ;;
  3*)
    $KIRA_MANAGER/menu/base-image-select.sh
    ;;
  4*)
    $KIRA_MANAGER/menu/node-type-select.sh
    ;;
  5*)
    set +x
    echoWarn "WARNING: Nodes launched in the private mode can only communicate via P2P with other nodes deployed in their local/private network"
    echoNErr "Launch $(globGet INFRA_MODE) node in [P]ublic or Pri[V]ate networking mode: " && pressToContinue p v && MODE=$(globGet OPTION)
    set -x

    [ "${MODE,,}" == "p" ] && globSet PRIVATE_MODE "false"
    [ "${MODE,,}" == "v" ] && globSet PRIVATE_MODE "true"
    ;;
  6*)
    $KIRA_MANAGER/kira/kira-backup.sh
    ;;
  7*)
     NEW_NETWORK="false"
     if [ "$(globGet INFRA_MODE)" == "validator" ]; then
         set +x
         echoNErr "Create [N]ew network or [J]oin existing one: " && pressToContinue n j
         set -x
         [ "$(globGet OPTION)" == "n" ] && NEW_NETWORK="true" || NEW_NETWORK="false"
     fi

     globSet NEW_NETWORK "$NEW_NETWORK"
     globSet NEW_NETWORK_NAME "localnet-1"
   ;;
   8*)
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
