#!/usr/local/bin/bash

set -e
export KIRA_WORKDIR=$(cd $(dirname $0) && pwd)

clear

chmod +x $KIRA_WORKDIR/utils.sh
source $KIRA_WORKDIR/utils.sh

printWidth=47
echo -e "-------------------------------------------------"
displayAlign center $printWidth "KIRA MANAGEMENT TOOL v$(cat $KIRA_WORKDIR/VERSION)"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
displayAlign center $printWidth "Deployment Mode"
displayAlign left $printWidth " [1] | Demo Mode (local testnet)"
displayAlign left $printWidth " [2] | Full Node Mode"
displayAlign left $printWidth " [3] | Validator Mode"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit | [W] | Refresh Window"
echo -e "-------------------------------------------------"

while :; do
  echo -en "Input option: "

  read -n 1 KEY

  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Demo Deployment..."
    chmod +x $KIRA_WORKDIR/deploy/start.sh
    $KIRA_WORKDIR/deploy/start.sh --demo
    break
    ;;

  2*)
    echo "INFO: Starting Full Node Deployment..."
    chmod +x $KIRA_WORKDIR/start.sh
    $KIRA_WORKDIR/start.sh --full
    break
    ;;

  3*)
    echo "INFO: Starting Validator Node Deployment..."
    chmod +x $KIRA_WORKDIR/start.sh
    $KIRA_WORKDIR/start.sh --validator
    break
    ;;

  x*)
    exit 0
    ;;

  *)
    echo "Try again."
    ;;
  esac
done
