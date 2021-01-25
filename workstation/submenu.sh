#!/bin/bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e

if [ "${INFRA_MODE,,}" == "local" ]; then
  title="Demo Mode (local testnet)"
elif [ "${INFRA_MODE,,}" == "sentry" ]; then
  title="Full Node Mode"
elif [ "${INFRA_MODE,,}" == "validator" ]; then
  title="Validator Mode"
else
  echo "ERROR: Unknown operation mode"
  exit 1
fi

SEKAI_BRANCH_DEFAULT=$SEKAI_BRANCH
FRONTEND_BRANCH_DEFAULT=$FRONTEND_BRANCH
INTERX_BRANCH_DEFAULT=$INTERX_BRANCH

[ -z "$SEKAI_BRANCH_DEFAULT" ] && SEKAI_BRANCH_DEFAULT="master"
[ -z "$FRONTEND_BRANCH_DEFAULT" ] && FRONTEND_BRANCH_DEFAULT="master"
[ -z "$INTERX_BRANCH_DEFAULT" ] && INTERX_BRANCH_DEFAULT="master"
[ -z "$IFACE" ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
[ -z "$PORTS_EXPOSURE" ] && PORTS_EXPOSURE="enabled"

set +x
printf "\033c"

printWidth=47
echo -e "\e[31;1m-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
echo -e "| Network Interface: $IFACE (default)" 
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

    if [ "${INFRA_MODE,,}" == "validator" ] ; then
        $KIRA_MANAGER/menu/network-select.sh # network selector allows for selecting snapshoot 
    else
        CDHelper text lineswap --insert="NETWORK_NAME=\"local-1\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    fi

    $KIRA_MANAGER/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure, try to 'reboot' your machine first"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    set -x
    $KIRA_MANAGER/kira/kira.sh
    exit 0
    ;;
  2*)
    echo "INFO: Starting Advanced Setup..."
    $KIRA_MANAGER/menu/branch-select.sh "false"
    
    if [ "${INFRA_MODE,,}" == "validator" ] ; then
        $KIRA_MANAGER/menu/network-select.sh # network selector allows for selecting snapshoot 
    else
        $KIRA_MANAGER/menu/snapshoot-select.sh
    fi
    
    $KIRA_MANAGER/menu/interface-select.sh
    
    $KIRA_MANAGER/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure, try to 'reboot' your machine first"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    set -x
    $KIRA_MANAGER/kira/kira.sh
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
