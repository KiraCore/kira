#!/bin/bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

if [ "${INFRA_MODE,,}" == "local" ]; then
  title="Demo Mode (local testnet)"
elif [ "${INFRA_MODE,,}" == "sentry" ]; then
  title="Sentry Mode"
elif [ "${INFRA_MODE,,}" == "validator" ]; then
  title="Validator Mode"
else
  echoErr "ERROR: Unknown operation mode"
  exit 1
fi

systemctl stop kirascan || echoWarn "WARNING: Could NOT stop kirascan service it was propably already stopped or does NOT exist yet"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service was not stopped"
globSet LATEST_BLOCK 0
globSet MIN_HEIGHT 0

SEKAI_BRANCH_DEFAULT=$SEKAI_BRANCH
FRONTEND_BRANCH_DEFAULT=$FRONTEND_BRANCH
INTERX_BRANCH_DEFAULT=$INTERX_BRANCH

[ -z "$SEKAI_BRANCH_DEFAULT" ] && SEKAI_BRANCH_DEFAULT="master"
[ -z "$FRONTEND_BRANCH_DEFAULT" ] && FRONTEND_BRANCH_DEFAULT="master"
[ -z "$INTERX_BRANCH_DEFAULT" ] && INTERX_BRANCH_DEFAULT="master"
[ -z "$IFACE" ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
[ -z "$PORTS_EXPOSURE" ] && PORTS_EXPOSURE="enabled"

CDHelper text lineswap --insert="GENESIS_SHA256=\"\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="AUTO_BACKUP_LAST_BLOCK=0" --prefix="AUTO_BACKUP_LAST_BLOCK=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=\"\"" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SNAP_EXPOSE=\"true\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
[ -z "$AUTO_BACKUP_ENABLED" ] && CDHelper text lineswap --insert="AUTO_BACKUP_INTERVAL=2" --prefix="AUTO_BACKUP_INTERVAL=" --path=$ETC_PROFILE --append-if-found-not=True
[ -z "$AUTO_BACKUP_ENABLED" ] && CDHelper text lineswap --insert="AUTO_BACKUP_ENABLED=\"true\"" --prefix="AUTO_BACKUP_ENABLED=" --path=$ETC_PROFILE --append-if-found-not=True

if [ "${INFRA_MODE,,}" == "validator" ] ; then
    MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS
    set +x
    source $MNEMONICS

    while (! $(isMnemonic "$VALIDATOR_ADDR_MNEMONIC")) ; do
        echoWarn "WARNING: Validator account private key (VALIDATOR_ADDR_MNEMONIC) is invalid or was NOT found within the private key store '$MNEMONICS'"
        echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read VALIDATOR_ADDR_MNEMONIC
        VALIDATOR_ADDR_MNEMONIC=$(echo "$VALIDATOR_ADDR_MNEMONIC" | xargs)
        if [ ! -z "$VALIDATOR_ADDR_MNEMONIC" ] && (! $(isMnemonic "$VALIDATOR_ADDR_MNEMONIC")) ; then
            echoErr "ERROR: Invalid Bip39 seed words sequence"
            continue
        elif [ -z "$VALIDATOR_ADDR_MNEMONIC" ] ; then
            echoInfo "INFO: New validator account controller key will be generated"
            CDHelper text lineswap --insert="VALIDATOR_ADDR_MNEMONIC=\"\"" --prefix="VALIDATOR_ADDR_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
        else 
            CDHelper text lineswap --insert="VALIDATOR_ADDR_MNEMONIC=\"$VALIDATOR_ADDR_MNEMONIC\"" --prefix="VALIDATOR_ADDR_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
            echoInfo "INFO: Validator controller key mnemonic (VALIDATOR_ADDR_MNEMONIC) will be saved to $MNEMONICS"
        fi
    done

    while (! $(isMnemonic "$VALIDATOR_VAL_MNEMONIC")) ; do
        echoWarn "WARNING: Validator signing private key (VALIDATOR_VAL_MNEMONIC) is invalid or was NOT found within the private key store '$MNEMONICS'"
        echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read VALIDATOR_VAL_MNEMONIC
        VALIDATOR_VAL_MNEMONIC=$(echo "$VALIDATOR_VAL_MNEMONIC" | xargs)
        if [ ! -z "$VALIDATOR_VAL_MNEMONIC" ] && (! $(isMnemonic "$VALIDATOR_VAL_MNEMONIC")) ; then
            echoErr "ERROR: Invalid Bip39 seed words sequence"
            continue
        elif [ -z "$VALIDATOR_VAL_MNEMONIC" ] ; then
            echoInfo "INFO: New validator signing key will be generated"
            CDHelper text lineswap --insert="VALIDATOR_VAL_MNEMONIC=\"\"" --prefix="VALIDATOR_VAL_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
        else 
            CDHelper text lineswap --insert="VALIDATOR_VAL_MNEMONIC=\"$VALIDATOR_VAL_MNEMONIC\"" --prefix="VALIDATOR_VAL_MNEMONIC=" --path=$MNEMONICS --append-if-found-not=True --silent=true
            echoInfo "INFO: Validator signing key mnemonic (VALIDATOR_VAL_MNEMONIC) will be saved to $MNEMONICS"
        fi
    done
    set -x
fi

set +x
printf "\033c"

printWidth=47
echo -e "\e[31;1m-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
echo -e "|       Network Interface: $IFACE (default)"
echo -e "|       Secrets Direcotry: $KIRA_SECRETS"
echo -e "|     Current kira Branch: $INFRA_BRANCH"
echo -e "|    Default sekai Branch: $SEKAI_BRANCH_DEFAULT"
echo -e "|   Default interx Branch: $INTERX_BRANCH_DEFAULT"
echo -e "| Default frontend Branch: $FRONTEND_BRANCH_DEFAULT"
echo -e "|-----------------------------------------------|"
displayAlign left $printWidth " [1] | Quick Setup $setupHintQuick"
displayAlign left $printWidth " [2] | Advanced Setup $setupHintAdvanced"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit"
echo -e "-------------------------------------------------\e[0m\c\n"
echo ""

FAILED="false"

while :; do
  read -n1 -p "Input option: " KEY
  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Quick Setup..."
    echo "NETWORK interface: $IFACE"

    $KIRA_MANAGER/menu/branch-select.sh "true"

    CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] ; then
        $KIRA_MANAGER/menu/quick-select.sh
    else
        CDHelper text lineswap --insert="NETWORK_NAME=\"local-1\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="NEW_NETWORK=\"true\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
        rm -fv "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$KIRA_SNAP_PATH" "$KIRA_SNAP/status/latest"
    fi
    break
    ;;
  2*)
    echo "INFO: Starting Advanced Setup..."
    $KIRA_MANAGER/menu/branch-select.sh "false"

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] ; then
        $KIRA_MANAGER/menu/network-select.sh # network selector allows for selecting snapshot
    else
        $KIRA_MANAGER/menu/snapshot-select.sh
    fi

    $KIRA_MANAGER/menu/seeds-select.sh
    $KIRA_MANAGER/menu/interface-select.sh
    break
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

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
SETUP_END_DT=""
CDHelper text lineswap --insert="SETUP_START_DT=\"$SETUP_START_DT\"" --prefix="SETUP_START_DT=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SETUP_END_DT=\"$SETUP_END_DT\"" --prefix="SETUP_END_DT=" --path=$ETC_PROFILE --append-if-found-not=True

set +e && source $ETC_PROFILE &>/dev/null && set -e

echoInfo "INFO: MTU Value Discovery..."
MTU=$(cat /sys/class/net/$IFACE/mtu || echo "1500")
(! $(isNaturalNumber $MTU)) && MTU=1500
(($MTU < 100)) && MTU=9000
globSet MTU $MTU

rm -rfv $KIRA_UPDATE

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

systemctl daemon-reload
systemctl enable kiraup
systemctl restart kiraup

echoInfo "INFO: Starting install logs preview, to exit type Ctrl+c"
sleep 2
journalctl --since "$SETUP_START_DT" -u kiraup -f --no-pager --output cat

$KIRA_MANAGER/kira/kira.sh

exit 0
