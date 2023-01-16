#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/launcher.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

systemctl stop kirascan || echoWarn "WARNING: KIRA scan service could NOT be stopped"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service could NOT be stopped"
systemctl stop kiraplan || echoWarn "WARNING: KIRA upgrade service could NOT be stopped"
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
sleep 1

timedatectl set-timezone "Etc/UTC" || ( echoErr "ERROR: Failed to set time zone to UTC, ensure to do that manually after setup is finalized!" && sleep 10 )

[ -z "$(globGet IFACE)" ] && globSet IFACE "$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)"
[ -z "$(globGet PORTS_EXPOSURE)" ] && globSet PORTS_EXPOSURE "enabled"

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

    CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)"
    HEIGHT="$(globGet TRUSTED_NODE_HEIGHT)"
    NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
    [ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"
    
    set +x
    printf "\033c"

    SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 9)
    P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 9)
    RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 9)
    GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 9)
    PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 9)
    INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 9)
    EXPOSURE="local networks" && [ "$(globGet PRIVATE_MODE)" == "false" ] && EXPOSURE="public networks"
    SNAPS="snap disabled" && [ "$(globGet SNAPSHOT_EXECUTE)" == "true" ] && SNAPS="snap enabled"
    LMODE="join existing net." && [ "$(globGet NEW_NETWORK)" == "true" ] && LMODE="create new net."

    SNAP_URL=$(globGet TRUSTED_SNAP_URL)
    SNAP_SIZE=$(globGet TRUSTED_SNAP_SIZE)
    
    prtChars=59
    prtCharsSub=33
    prtCharsSubMax=50
    echo -e "\e[31;1m============================================================="
    echo -e "|$(strFixC "$(toUpper $(globGet INFRA_MODE)) NODE LAUNCHER, KM $KIRA_SETUP_VER" $prtChars)|"
    echo -e "|$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " $prtChars "." "-")|"
    echo -e "|   SSH   |   P2P   |   RPC   |   GRPC  | MONITOR | INTERX  |"
    echo -e "|$SSH_PORT|$P2P_PORT|$RPC_PORT|$GRPC_PORT|$PRTH_PORT|$INEX_PORT|"
    echo -e "|-----------------------------------------------------------|"
    [ "$(globGet NEW_NETWORK)" == "false" ] && \
    echo -e "|        Network Name: $(strFixL "$CHAIN_ID" $prtCharsSubMax)"
    echo -e "|   Secrets Direcotry: $(strFixL "$KIRA_SECRETS" $prtCharsSubMax)"
    echo -e "| Snapshots Direcotry: $(strFixL "$KIRA_SNAP" $prtCharsSubMax)"
    [ "$(globGet NEW_NETWORK)" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echo -e "|      Local Snapshot: $(strFixL "$KIRA_SNAP_PATH" $prtCharsSubMax)"
    [ "$(globGet NEW_NETWORK)" != "true" ] && [[ $SNAP_SIZE -gt 0 ]] && \
    echo -e "|   External Snapshot: $(strFixL "$SNAP_URL" $prtCharsSubMax)"
    echo -e "|   Base Image Source: $(strFixL "$(globGet NEW_BASE_IMAGE_SRC)" $prtCharsSubMax)"
    echo -e "|  KIRA Manger Source: $(strFixL "$(globGet INFRA_SRC)" $prtCharsSubMax)"
    echo -e "|-----------------------------------------------------------|"
    echo -e "| [1] | Change Default Net. Interface : $(strFixL "$(globGet IFACE)" 20)|"
    echo -e "| [2] | Change Default Port Numbers   : $(strFixL "" 20)|"
    echo -e "| [3] | Change Base Image URL         : $(strFixL "" 20)|"
    echo -e "| [4] | Change Node Type              : $(strFixL "$(globGet INFRA_MODE)" 20)|"
    echo -e "| [5] | Change Network Exposure       : $(strFixL "$EXPOSURE" 20)|"
    echo -e "| [6] | Change Snapshots Config.      : $(strFixL "$SNAPS" 20)|"
    echo -e "| [7] | Change Network Launch Mode    : $(strFixL "$LMODE" 20)|"
    [ "$(globGet NEW_NETWORK)" == "true" ] && \
    echo -e "| [8] | Change Network Name           : $(strFixL "$(globGet NEW_NETWORK_NAME)" 20)|" || \
    echo -e "| [8] | Change Trusted Node Address   : $(strFixL "$NODE_ADDR" 20)|"
    echo -e "|-----------------------------------------------------------|"
    echo -e "| [S] | Start Setup   | [R] Refresh   | [X] Abort Setup     |"
    echo -e "-------------------------------------------------------------\e[0m\c\n"
    echo ""
    FAILED="false"
  
    if [ "$REINITALIZE_NODE" != "true" ] && [ $HEIGHT -le 0 ] ; then
        echoWarn "WARNINIG: Trusted seed is unavilable, change node address to start setup..."
        echoNErr "Input option: " && pressToContinue 1 2 3 4 5 6 7 8 r x && KEY=$(globGet OPTION) && echo ""
    else
        echoNErr "Input option: " && pressToContinue 1 2 3 4 5 6 7 8 s r x && KEY=$(globGet OPTION) && echo ""
    fi

  case ${KEY,,} in
  s*)
    echo "INFO: Starting Quick Setup..."
    setGlobEnv KIRA_SNAP_PATH ""
    globSet BASE_IMAGE_SRC "$(globGet NEW_BASE_IMAGE_SRC)"
    $KIRA_MANAGER/menu/quick-select.sh
    break
    ;;
  1*)
    $KIRA_MANAGER/menu/interface-select.sh
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
