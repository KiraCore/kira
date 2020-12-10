#!/bin/bash

set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

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
    source $KIRA_WORKSTATION/submenu.sh --demo
    break
    ;;

  x*)
    exit 0
    ;;

  2*)
    echo "INFO: Starting Full Node Deployment..."
    echo "Full Node Deployment mode is not yet ready. Please select other option."
    # source $KIRA_WORKSTATION/submenu.sh --full
    ;;

  3*)
    echo "INFO: Starting Validator Node Deployment..."
    echo "Validator Node Deployment mode is not yet ready. Please select other option."
    # source $KIRA_WORKSTATION/submenu.sh --validator
    ;;

  *)
    echo "Try again."
    ;;
  esac
done
