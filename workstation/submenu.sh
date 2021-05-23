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
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
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
[ -z "$DEPLOYMENT_MODE" ] && DEPLOYMENT_MODE="minimal"

CDHelper text lineswap --insert="DEPLOYMENT_MODE=$DEPLOYMENT_MODE" --prefix="DEPLOYMENT_MODE=" --path=$ETC_PROFILE --append-if-found-not=True

timerDel AUTO_BACKUP
globDel VALIDATOR_ADDR
globSet SNAP_EXPOSE "true"

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
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(n|j)$ ]]; do echoNErr "Create [N]ew network or [J]oin existing one: " && read -d'' -s -n1 SELECT && echo ""; done
    set -x
    [ "${SELECT,,}" == "n" ] && NEW_NETWORK="true" || NEW_NETWORK="false"
else
    NEW_NETWORK="false"
fi

CDHelper text lineswap --insert="NEW_NETWORK=\"$NEW_NETWORK\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
[ "${NEW_NETWORK,,}" == "true" ] && $KIRA_MANAGER/menu/chain-id-select.sh

while :; do
    set +e && source $ETC_PROFILE &>/dev/null && set -e
    set +x
    printf "\033c"

    printWidth=47
    echo -e "\e[31;1m-------------------------------------------------"
    displayAlign center $printWidth "$title"
    displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "|-----------------------------------------------|"
    echo -e "|       Network Interface: $IFACE (default)"
    echo -e "|        Exposed SSH Port: $DEFAULT_SSH_PORT"
    echo -e "|         Deployment Mode: ${DEPLOYMENT_MODE^^}"
    echo -e "|  NEW Network Deployment: ${NEW_NETWORK^^}"
[ "${NEW_NETWORK,,}" == "true" ] && \
    echo -e "|        NEW Network Name: ${NETWORK_NAME}"
    echo -e "|       Secrets Direcotry: $KIRA_SECRETS"
    echo -e "|     Snapshots Direcotry: $KIRA_SNAP"
    echo -e "|     Current kira Branch: $INFRA_BRANCH"
    echo -e "|    Default sekai Branch: $SEKAI_BRANCH_DEFAULT"
    echo -e "|   Default interx Branch: $INTERX_BRANCH_DEFAULT"
    echo -e "| Default frontend Branch: $FRONTEND_BRANCH_DEFAULT"
    echo -e "|-----------------------------------------------|"
    displayAlign left $printWidth " [1] | Change Default Network Interface"
    displayAlign left $printWidth " [2] | Change SSH Port to Expose"
    displayAlign left $printWidth " [3] | Change Default Branches"
    displayAlign left $printWidth " [4] | Change Deployment Mode"
    echo "|-----------------------------------------------|"
    displayAlign left $printWidth " [S] | Start Node Setup"
    displayAlign left $printWidth " [R] | Return to Main Menu"
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
    CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
        $KIRA_MANAGER/menu/quick-select.sh
    else
        rm -fv "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$KIRA_SNAP_PATH" "$KIRA_SNAP/status/latest"
    fi
    break
    ;;
#  a*)
#    echo "INFO: Starting Advanced Setup..."
#    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
#        $KIRA_MANAGER/menu/network-select.sh # network selector allows for selecting snapshot
#    else
#        $KIRA_MANAGER/menu/snapshot-select.sh
#    fi
#
#    $KIRA_MANAGER/menu/seeds-select.sh
#    break
#    ;;
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
    set +x
    echoWarn "WARNING: Deploying your node in minimal mode will disable automated snapshots and only start essential containers!"
    MODE="." && while ! [[ "${MODE,,}" =~ ^(m|f)$ ]]; do echoNErr "Launch $INFRA_MODE node in [M]inimal or [F]ull deployment mode: " && read -d'' -s -n1 MODE && echo ""; done
    set -x

    [ "${MODE,,}" == "m" ] && DEPLOYMENT_MODE="minimal"
    [ "${MODE,,}" == "f" ] && DEPLOYMENT_MODE="full"

    CDHelper text lineswap --insert="DEPLOYMENT_MODE=\"$DEPLOYMENT_MODE\"" --prefix="DEPLOYMENT_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    ;;
  r*)
    $KIRA_MANAGER/menu.sh
    exit 0
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

if [ "${DEPLOYMENT_MODE,,}" == "minimal" ] ; then
    globSet AUTO_BACKUP "false"
    if [[ "${INFRA_MODE,,}" =~ ^(validator|seed)$ ]] ; then
        INFRA_CONTAINER_COUNT=2
    elif [[ "${INFRA_MODE,,}" =~ ^(sentry|local)$ ]] ; then
        INFRA_CONTAINER_COUNT=4
    else
        echoErr "ERROR: Unknown infra mode $INFRA_MODE"
        exit 1
    fi
else
    if [[ "${INFRA_MODE,,}" =~ ^(validator)$ ]] ; then
        INFRA_CONTAINER_COUNT=5
    elif [[ "${INFRA_MODE,,}" =~ ^(sentry|local)$ ]] ; then
        INFRA_CONTAINER_COUNT=4
    elif [[ "${INFRA_MODE,,}" =~ ^(seed)$ ]] ; then
        INFRA_CONTAINER_COUNT=3
    else
        echoErr "ERROR: Unknown infra mode $INFRA_MODE"
        exit 1
    fi
fi

CDHelper text lineswap --insert="INFRA_CONTAINER_COUNT=\"$INFRA_CONTAINER_COUNT\"" --prefix="INFRA_CONTAINER_COUNT=" --path=$ETC_PROFILE --append-if-found-not=True

if (! $(isBoolean "$(globGet AUTO_BACKUP)")) ; then
    CDHelper text lineswap --insert="AUTO_BACKUP_INTERVAL=2" --prefix="AUTO_BACKUP_INTERVAL=" --path=$ETC_PROFILE --append-if-found-not=True
    globSet AUTO_BACKUP "true"
fi

CDHelper text lineswap --insert="PORTS_EXPOSURE=enabled" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
SETUP_END_DT=""
CDHelper text lineswap --insert="SETUP_START_DT=\"$SETUP_START_DT\"" --prefix="SETUP_START_DT=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SETUP_END_DT=\"$SETUP_END_DT\"" --prefix="SETUP_END_DT=" --path=$ETC_PROFILE --append-if-found-not=True

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

systemctl daemon-reload
systemctl enable kiraup
systemctl restart kiraup

echoInfo "INFO: Starting install logs preview, to exit type Ctrl+c"
sleep 2
journalctl --since "$SETUP_START_DT" -u kiraup -f --no-pager --output cat

$KIRA_MANAGER/kira/kira.sh

exit 0
