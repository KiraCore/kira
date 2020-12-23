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

set +x
clear

printWidth=47
echo -e "\e[31;1m-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
displayAlign left $printWidth " [1] | Quick Setup"
displayAlign left $printWidth " [2] | Advanced Setup"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit"
echo -e "-------------------------------------------------\e[0m\c\n"
echo ""

SEKAI_BRANCH_DEFAULT="v0.1.7.4"
FRONTEND_BRANCH_DEFAULT="dev"
INTERX_BRANCH_DEFAULT="interx"
FAILED="false"

while :; do
  read -n1 -p "Input option: " KEY
  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Quick Setup..."
    echo "SEKAI_BRANCH = $SEKAI_BRANCH_DEFAULT"
    echo "FRONTEND_BRANCH = $FRONTEND_BRANCH_DEFAULT"
    echo "INTERX_BRANCH = $INTERX_BRANCH_DEFAULT"

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH_DEFAULT" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True

    $KIRA_WORKSTATION/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure"
    read -p "Press any key to continue..." -n 1
    set -x
    source $KIRA_WORKSTATION/kira/kira.sh
    break
    ;;

  2*)
    echo "INFO: Starting Advanced Setup..."
    echo "Please select each repo's branches. (Press Enter for default)"
    echo ""

    read -p "Input Sekai Branch (Default: $SEKAI_BRANCH_DEFAULT): " SEKAI_BRANCH
    read -p "Input Kira Frontend Branch (Default: $FRONTEND_BRANCH_DEFAULT): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: $INTERX_BRANCH_DEFAULT): " INTERX_BRANCH

    [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT
    [ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT
    [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH=$INTERX_BRANCH_DEFAULT

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True

    $KIRA_WORKSTATION/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure"
    read -p "Press any key to continue..." -n 1
    set -x
    source $KIRA_WORKSTATION/kira/kira.sh
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