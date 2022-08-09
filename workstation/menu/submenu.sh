#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e

if [ "${INFRA_MODE,,}" == "seed" ]; then
  title="Seed Mode"
elif [ "${INFRA_MODE,,}" == "sentry" ]; then
  title="Sentry Mode"
elif [ "${INFRA_MODE,,}" == "validator" ]; then
  title="Validator Mode"
else
  echoErr "ERROR: Unknown operation mode"
  exit 1
fi

systemctl stop kirascan || echoWarn "WARNING: KIRA scan service could NOT be stopped"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service could NOT be stopped"
systemctl stop kiraplan || echoWarn "WARNING: KIRA upgrade service could NOT be stopped"
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
sleep 1

timedatectl set-timezone "Etc/UTC" || ( echoErr "ERROR: Failed to set time zone to UTC, ensure to do that manually after setup is finalized!" && sleep 10 )

[ -z "$IFACE" ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
[ -z "$(globGet PORTS_EXPOSURE)" ] && globSet PORTS_EXPOSURE "enabled"

if [ "${INFRA_MODE,,}" == "validator" ] ; then
    MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS
    set +x
    source $MNEMONICS

    while (! $(isMnemonic "$VALIDATOR_ADDR_MNEMONIC")) ; do
        echoInfo "INFO: Private key store location: '$MNEMONICS'"
        echoWarn "WARNING: Validator account private key (VALIDATOR_ADDR_MNEMONIC) is invalid or was NOT found within the key store"
        echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read VALIDATOR_ADDR_MNEMONIC
        VALIDATOR_ADDR_MNEMONIC=$(echo "$VALIDATOR_ADDR_MNEMONIC" | xargs 2> /dev/null || echo -n "")
        VALIDATOR_ADDR_MNEMONIC=$(echo ${VALIDATOR_ADDR_MNEMONIC//,/ })
        if ($(isNullOrWhitespaces "$VALIDATOR_ADDR_MNEMONIC")) ; then
            echoInfo "INFO: New validator account controller key will be generated"
            VALIDATOR_ADDR_MNEMONIC=""
        elif ($(isMnemonic "$VALIDATOR_ADDR_MNEMONIC")) ; then
            echoInfo "INFO: Validator controller key mnemonic (VALIDATOR_ADDR_MNEMONIC) is valid and will be saved to keystore"
        else
            echoErr "ERROR: Invalid Bip39 seed words sequence"
            continue
        fi

        setVar VALIDATOR_ADDR_MNEMONIC "$VALIDATOR_ADDR_MNEMONIC" "$MNEMONICS" 1> /dev/null
        break
    done
    
    while (! $(isMnemonic "$VALIDATOR_VAL_MNEMONIC")) ; do
        echoInfo "INFO: Private key store location: '$MNEMONICS'"
        echoWarn "WARNING: Validator signing private key (VALIDATOR_VAL_MNEMONIC) is invalid or was NOT found within the key store"
        echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read VALIDATOR_VAL_MNEMONIC
        VALIDATOR_VAL_MNEMONIC=$(echo "$VALIDATOR_VAL_MNEMONIC" | xargs 2> /dev/null || echo -n "")
        VALIDATOR_VAL_MNEMONIC=$(echo ${VALIDATOR_VAL_MNEMONIC//,/ })
        if ($(isNullOrWhitespaces "$VALIDATOR_VAL_MNEMONIC")) ; then
            echoInfo "INFO: New validator signing key will be generated"
            VALIDATOR_VAL_MNEMONIC=""
        elif ($(isMnemonic "$VALIDATOR_VAL_MNEMONIC")) ; then
            echoInfo "INFO: Validator signing key mnemonic (VALIDATOR_VAL_MNEMONIC)  is valid and will be saved to keystore"
        else
            echoErr "ERROR: Invalid Bip39 seed words sequence"
            continue
        fi

        setVar VALIDATOR_VAL_MNEMONIC "$VALIDATOR_VAL_MNEMONIC" "$MNEMONICS" 1> /dev/null
        break
    done
    set -x
fi

echo "INFO: Loading secrets..."
set +e
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

NEW_NETWORK="false"
if [ "${INFRA_MODE,,}" == "validator" ]; then
    set +x
    echoNErr "Create [N]ew network or [J]oin existing one: " && pressToContinue n j
    set -x
    [ "$(globGet OPTION)" == "n" ] && NEW_NETWORK="true" || NEW_NETWORK="false"
fi

globSet NEW_NETWORK "$NEW_NETWORK"
[ "${NEW_NETWORK,,}" == "true" ] && $KIRA_MANAGER/menu/chain-id-select.sh
[ -z "$(globGet SNAPSHOT_EXECUTE)" ] && globSet SNAPSHOT_EXECUTE "true"

PRIVATE_MODE=$(globGet PRIVATE_MODE) && (! $(isBoolean "$PRIVATE_MODE")) && PRIVATE_MODE="false" && globSet PRIVATE_MODE "$PRIVATE_MODE"

while :; do
    loadGlobEnvs
    set +x
    printf "\033c"

    printWidth=47
    echo -e "\e[31;1m-------------------------------------------------"
    displayAlign center $printWidth "$title $KIRA_SETUP_VER"
    displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "|-----------------------------------------------|"
    echo -e "|       Network Interface: $IFACE (default)"
    echo -e "|        Exposed SSH Port: $DEFAULT_SSH_PORT"
    echo -e "|            Privacy Mode: ${PRIVATE_MODE^^}"
    echo -e "|  NEW Network Deployment: $(globGet NEW_NETWORK)"
    [ "${NEW_NETWORK,,}" == "true" ] && \
    echo -e "|        NEW Network Name: ${NEW_NETWORK_NAME}"
    [ "${NEW_NETWORK,,}" != "true" ] && \
    echo -e "|            Network Name: ${NETWORK_NAME}"
    echo -e "|       Secrets Direcotry: $KIRA_SECRETS"
    echo -e "|     Snapshots Direcotry: $KIRA_SNAP"
    echo -e "|       Snapshots Enabled: $(globGet SNAPSHOT_EXECUTE)"
    [ "${NEW_NETWORK,,}" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echo -e "| Latest (local) Snapshot: $KIRA_SNAP_PATH" && \
    echo -e "|     Current kira Branch: $INFRA_BRANCH"
    echo -e "|      Base Image Version: $KIRA_BASE_VERSION"
    echo -e "|-----------------------------------------------|"
    displayAlign left $printWidth " [1] | Change Default Network Interface"
    displayAlign left $printWidth " [2] | Change SSH Port to Expose"
    displayAlign left $printWidth " [3] | Change Default Branches"
    displayAlign left $printWidth " [4] | Change Node Type (sentry/seed/validator)"
    displayAlign left $printWidth " [5] | Change Network Exposure (privacy) Mode"
    displayAlign left $printWidth " [6] | Change Snapshots Configuration"
    echo "|-----------------------------------------------|"
    displayAlign left $printWidth " [S] | Start Node Setup"
    displayAlign left $printWidth " [X] | Exit"
    echo -e "-------------------------------------------------\e[0m\c\n"
    echo ""
    FAILED="false"
  
    read -n1 -p "Input option: " KEY
    echo ""

  case ${KEY,,} in
  s*)
    echo "INFO: Starting Quick Setup..."
    echo "NETWORK interface: $IFACE"
    setGlobEnv IFACE "$IFACE"
    setGlobEnv KIRA_SNAP_PATH ""

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
        $KIRA_MANAGER/menu/quick-select.sh
    else
        echoErr "ERROR: Unknown infra mode '$INFRA_MODE'"
        sleep 10
        continue
    fi
    break
    ;;
  1*)
    $KIRA_MANAGER/menu/interface-select.sh
    continue
    ;;
  2*)
    DEFAULT_SSH_PORT="." && while (! $(isPort "$DEFAULT_SSH_PORT")); do echoNErr "Input SSH port number to expose: " && read DEFAULT_SSH_PORT ; done
    set -x
    setGlobEnv DEFAULT_SSH_PORT "$DEFAULT_SSH_PORT"
    continue
    ;;
  3*)
    $KIRA_MANAGER/menu/branch-select.sh "false"
    continue
    ;;
  4*)
    $KIRA_MANAGER/menu/menu.sh "false"
    exit 0
    ;;
  5*)
    set +x
    echoWarn "WARNING: Nodes launched in the private mode can only communicate via P2P with other nodes deployed in their local/private network"
    echoNErr "Launch $INFRA_MODE node in [P]ublic or Pri[V]ate networking mode: " && pressToContinue p v && MODE=$(globGet OPTION)
    set -x

    [ "${MODE,,}" == "p" ] && globSet PRIVATE_MODE "false"
    [ "${MODE,,}" == "v" ] && globSet PRIVATE_MODE "true"
    ;;
  6*)
    $KIRA_MANAGER/kira/kira-backup.sh
    continue
    ;;
  x*)
    exit 0
    ;;
  *)
    echo "Try again."
    sleep 1
    ;;
  esac
done
set -x

globDel "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "CONTAINERS_UPDATED_$KIRA_SETUP_VER" UPGRADE_PLAN
globDel "sentry_SEKAID_STATUS" "validator_SEKAID_STATUS" "seed_SEKAID_STATUS" "interx_SEKAID_STATUS"
globDel VALIDATOR_ADDR UPDATE_FAIL_COUNTER SETUP_END_DT SETUP_REBOOT UPDATE_CONTAINERS_LOG UPDATE_CLEANUP_LOG UPDATE_TOOLS_LOG LATEST_STATUS SNAPSHOT_TARGET
[ -z "$(globGet SNAP_EXPOSE)" ] && globSet SNAP_EXPOSE "true"
[ -z "$(globGet SNAPSHOT_KEEP_OLD)" ] && globSet SNAPSHOT_KEEP_OLD "true"
globSet UPDATE_DONE "false"
globSet UPDATE_FAIL "false"

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
globSet SETUP_START_DT "$SETUP_START_DT"
globSet PORTS_EXPOSURE "enabled"

rm -fv $(globFile validator_SEKAID_STATUS) $(globFile sentry_SEKAID_STATUS) 
rm -fv $(globFile seed_SEKAID_STATUS) $(globFile interx_SEKAID_STATUS)

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
