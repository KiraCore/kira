#!/bin/bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

if [ "${INFRA_MODE,,}" == "local" ]; then
  title="Demo Mode (local testnet)"
elif [ "${INFRA_MODE,,}" == "seed" ]; then
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
globSet LATEST_BLOCK_HEIGHT 0
globSet LATEST_BLOCK_TIME 0
globSet MIN_HEIGHT 0

timedatectl set-timezone "Etc/UTC"

SEKAI_BRANCH_DEFAULT=$SEKAI_BRANCH
FRONTEND_BRANCH_DEFAULT=$FRONTEND_BRANCH
INTERX_BRANCH_DEFAULT=$INTERX_BRANCH

[ -z "$SEKAI_BRANCH_DEFAULT" ] && SEKAI_BRANCH_DEFAULT="master"
[ -z "$FRONTEND_BRANCH_DEFAULT" ] && FRONTEND_BRANCH_DEFAULT="master"
[ -z "$INTERX_BRANCH_DEFAULT" ] && INTERX_BRANCH_DEFAULT="master"
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

        CDHelper text lineswap --insert="VALIDATOR_ADDR_MNEMONIC=\"$VALIDATOR_ADDR_MNEMONIC\"" --prefix="VALIDATOR_ADDR_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
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

        CDHelper text lineswap --insert="VALIDATOR_VAL_MNEMONIC=\"$VALIDATOR_VAL_MNEMONIC\"" --prefix="VALIDATOR_VAL_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
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

if [ "${INFRA_MODE,,}" == "local" ]; then
    NEW_NETWORK="true"
elif [ "${INFRA_MODE,,}" == "validator" ]; then
    set +x
    echoNErr "Create [N]ew network or [J]oin existing one: " && pressToContinue n j
    set -x
    [ "$(globGet OPTION)" == "n" ] && NEW_NETWORK="true" || NEW_NETWORK="false"
else
    NEW_NETWORK="false"
fi

CDHelper text lineswap --insert="NEW_NETWORK=\"$NEW_NETWORK\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
globSet NEW_NETWORK "$NEW_NETWORK"
[ "${NEW_NETWORK,,}" == "true" ] && $KIRA_MANAGER/menu/chain-id-select.sh

PRIVATE_MODE=$(globGet PRIVATE_MODE) && (! $(isBoolean "$PRIVATE_MODE")) && PRIVATE_MODE="false" && globSet PRIVATE_MODE "$PRIVATE_MODE"

while :; do
    set +e && source $ETC_PROFILE &>/dev/null && set -e
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
    echo -e "|  NEW Network Deployment: ${NEW_NETWORK^^}"
    [ "${NEW_NETWORK,,}" == "true" ] && \
    echo -e "|        NEW Network Name: ${NETWORK_NAME}"
    echo -e "|       Secrets Direcotry: $KIRA_SECRETS"
    echo -e "|     Snapshots Direcotry: $KIRA_SNAP"
    [ "${NEW_NETWORK,,}" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echo -e "| Latest (local) Snapshot: $KIRA_SNAP_PATH" && \
    [ "${NEW_NETWORK,,}" != "true" ] && [ ! -z "$KIRA_SNAP_SHA256" ] && \
    echo -e "|       Snapshot Checksum: $KIRA_SNAP_SHA256"
    echo -e "|     Current kira Branch: $INFRA_BRANCH"
    echo -e "|    Default sekai Branch: $SEKAI_BRANCH"
    echo -e "|   Default interx Branch: $INTERX_BRANCH"
    echo -e "| Default frontend Branch: $FRONTEND_BRANCH"
    echo -e "|-----------------------------------------------|"
    displayAlign left $printWidth " [1] | Change Default Network Interface"
    displayAlign left $printWidth " [2] | Change SSH Port to Expose"
    displayAlign left $printWidth " [3] | Change Default Branches"
    displayAlign left $printWidth " [4] | Change Infrastructure Mode"
    displayAlign left $printWidth " [5] | Change Network Exposure (privacy) Mode"
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
    CDHelper text lineswap --insert="IFACE=\"$IFACE\"" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
        $KIRA_MANAGER/menu/quick-select.sh
    else
        rm -fv "$PUBLIC_PEERS" "$PUBLIC_SEEDS" "$KIRA_SNAP_PATH" "$KIRA_SNAP/status/latest"
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
    CDHelper text lineswap --insert="DEFAULT_SSH_PORT=\"$DEFAULT_SSH_PORT\"" --prefix="DEFAULT_SSH_PORT=" --path=$ETC_PROFILE --append-if-found-not=True
    continue
    ;;
  3*)
    $KIRA_MANAGER/menu/branch-select.sh "false"
    continue
    ;;
  4*)
    $KIRA_MANAGER/menu.sh "false"
    exit 0
    ;;
  5*)
    set +x
    echoWarn "WARNING: Nodes launched in the private mode can only communicate via P2P with other nodes deployed in their local/private network"
    echoNErr "Launch $INFRA_MODE node in [P]ublic or Pri[V]ate networking mode: " && pressToContinue p v && MODE=($(globGet OPTION))
    set -x

    [ "${MODE,,}" == "p" ] && globSet PRIVATE_MODE "false"
    [ "${MODE,,}" == "v" ] && globSet PRIVATE_MODE "true"
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

globDel VALIDATOR_ADDR UPDATE_FAIL_COUNTER SETUP_END_DT SETUP_REBOOT UPDATE_CONTAINERS_LOG UPDATE_CLEANUP_LOG UPDATE_TOOLS_LOG LATEST_STATUS SNAPSHOT_TARGET
[ -z "$(globGet SNAP_EXPOSE)" ] && globSet SNAP_EXPOSE "true"
[ -z "$(globGet SNAPSHOT_KEEP_OLD)" ] && globSet SNAPSHOT_KEEP_OLD "true"
globSet SNAPSHOT_EXECUTE "false"
globSet LATEST_BLOCK 0
globSet UPDATE_DONE "false"
globSet UPDATE_FAIL "false"

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
globSet SETUP_START_DT "$SETUP_START_DT"
globSet PORTS_EXPOSURE "enabled"

rm -fv $(globFile validator_SEKAID_STATUS)
rm -fv $(globFile sentry_SEKAID_STATUS)
rm -fv $(globFile seed_SEKAID_STATUS)

UPGRADE_NAME=$(cat $KIRA_INFRA/upgrade || echo "")
globSet UPGRADE_NAME "$UPGRADE_NAME"
globSet UPGRADE_DONE "true"
globSet UPGRADE_TIME "0"
globSet AUTO_UPGRADES "true"
globSet PLAN_DONE "true"
globSet PLAN_FAIL "false"
globSet PLAN_FAIL_COUNT "0"
globSet PLAN_START_DT "$(date +'%Y-%m-%d %H:%M:%S')"
globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"

set +e && source $ETC_PROFILE &>/dev/null && set -e

echoInfo "INFO: MTU Value Discovery..."
MTU=$(cat /sys/class/net/$IFACE/mtu || echo "1500")
(! $(isNaturalNumber $MTU)) && MTU=1500
(($MTU < 100)) && MTU=900
globSet MTU $MTU

rm -rfv "$KIRA_UPDATE" "$KIRA_DUMP/kiraup-done.log.txt" "$KIRA_DUMP/kirascan-done.log.txt"

cat > /etc/systemd/system/kiraup.service << EOL
[Unit]
Description=KIRA Update And Setup Service
After=network.target
[Service]
CPUWeight=20
CPUQuota=85%
IOWeight=20
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/update.sh
Restart=always
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

cat > /etc/systemd/system/kiraplan.service << EOL
[Unit]
Description=KIRA Upgrade Plan Service
After=network.target
[Service]
CPUWeight=100
CPUQuota=100%
IOWeight=100
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/plan.sh
Restart=always
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

systemctl daemon-reload
systemctl enable kiraup
systemctl enable kiraplan
systemctl restart kiraup
systemctl stop kiraplan || echoWarn "WARNING: Failed to stop KIRA Plan!"

echoInfo "INFO: Starting install logs preview, to exit type Ctrl+c"
sleep 2
journalctl --since "$SETUP_START_DT" -u kiraup -f --no-pager --output cat

$KIRA_MANAGER/kira/kira.sh

exit 0
