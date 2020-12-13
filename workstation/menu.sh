#!/bin/bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e

clear

source $KIRA_WORKSTATION/utils.sh

printWidth=47
echo -e "-------------------------------------------------"
displayAlign center $printWidth "KIRA DEPLOYMENT TOOL v$(cat $KIRA_WORKSTATION/VERSION)"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
displayAlign center $printWidth "Select Deployment Mode"
displayAlign left $printWidth " [1] | Demo Mode (local testnet)"
# displayAlign left $printWidth " [2] | Full Node Mode (Not ready yet)"
# displayAlign left $printWidth " [3] | Validator Mode (Not ready yet)"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit"
echo -e "-------------------------------------------------"

while :; do
  read -p "Input option: " KEY

  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Demo Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=local" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INFRA_CONTAINER_COUNT=6" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    break
    ;;

  x*)
    exit 0
    ;;

  2*)
    echo "INFO: Starting Full Node Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=sentry" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    echo "Full Node Deployment mode is not yet ready. Please select other option."
    ;;

  3*)
    echo "INFO: Starting Validator Node Deployment..."
    CDHelper text lineswap --insert="INFRA_MODE=validator" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    echo "Validator Node Deployment mode is not yet ready. Please select other option."
    ;;

  *)
    echo "Try again."
    sleep 1
    ;;
  esac
done

source $KIRA_WORKSTATION/submenu.sh