#!/usr/local/bin/bash

set -e
export KIRA_WORKDIR=$(cd $(dirname $0) && pwd)

clear

echo -e "-------------------------------------------------"
echo "|         KIRA MANAGEMENT TOOL $(cat $KIRA_WORKDIR/VERSION)           |"
echo "|             $(date '+%d/%m/%Y %H:%M:%S')               |"
echo -e "|-----------------------------------------------|"
echo "|               Deployment Mode                 |"
echo "| [1] | Demo Mode (local testnet)               |"
echo "| [2] | Full Node Mode                          |"
echo "| [3] | Validator Mode                          |"
echo "|-----------------------------------------------|"
echo "| [X] | Exit | [W] | Refresh Window | [Y] Debug |"
echo -e "-------------------------------------------------"

while :; do
  echo -en "Input option then press [ENTER] or [SPACE]: "

  read -n 1 -t 5 KEY

  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Demo Deployment"
    break
    ;;

  2*)
    echo "INFO: Starting Full Node Deployment"
    break
    ;;

  3*)
    echo "INFO: Starting Validator Node Deployment"
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
