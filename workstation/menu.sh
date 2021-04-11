#!/bin/bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set +x

printf "\033c"
printWidth=47
echo -e "\e[31;1m-------------------------------------------------"
displayAlign center $printWidth "KIRA DEPLOYMENT TOOL v$(cat $KIRA_MANAGER/VERSION)"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
displayAlign center $printWidth "Select Deployment Mode"
displayAlign left $printWidth " [1] | Demo Mode (local testnet only)"
displayAlign left $printWidth " [2] | Validator Mode (mainnet / testnet)"
displayAlign left $printWidth " [3] | Sentry Mode (mainnet / testnet)"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit"
echo -e "-------------------------------------------------\e[0m\c"
echo ""

while :; do
  read -n1 -p "Input option: " KEY
  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Demo Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=local" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INFRA_CONTAINER_COUNT=5" --prefix="INFRA_CONTAINER_COUNT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FIREWALL_ZONE=demo" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
    CDHelper text lineswap --insert="PORTS_EXPOSURE=enabled" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    break
    ;;
  2*)
    echo "INFO: Starting Validator Node Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=validator" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INFRA_CONTAINER_COUNT=5" --prefix="INFRA_CONTAINER_COUNT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FIREWALL_ZONE=validator" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
    CDHelper text lineswap --insert="PORTS_EXPOSURE=enabled" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True # IMPORTANT: DISABLE IN MAINNET RELEASE
    break
    ;;

  3*)
    echo "INFO: Starting Sentry Mode Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=sentry" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INFRA_CONTAINER_COUNT=5" --prefix="INFRA_CONTAINER_COUNT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FIREWALL_ZONE=sentry" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
    CDHelper text lineswap --insert="PORTS_EXPOSURE=enabled" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
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

source $KIRA_MANAGER/submenu.sh
