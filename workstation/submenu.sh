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

clear

printWidth=47
echo -e "-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
displayAlign left $printWidth " [1] | Quick Setup"
displayAlign left $printWidth " [2] | Advanced Setup"
echo "|-----------------------------------------------|"
displayAlign left $printWidth " [X] | Exit"
echo -e "-------------------------------------------------"

SEKAI_BRANCH_DEFAULT="v0.1.7.4"
FRONTEND_BRANCH_DEFAULT="dev"
INTERX_BRANCH_DEFAULT="interx"
KMS_BRANCH_DEFAULT="develop"

while :; do
  read -p "Input option: " KEY

  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Quick Setup..."
    echo "SEKAI_BRANCH = $SEKAI_BRANCH_DEFAULT"
    echo "FRONTEND_BRANCH = $FRONTEND_BRANCH_DEFAULT"
    echo "INTERX_BRANCH = $INTERX_BRANCH_DEFAULT"
    echo "KMS_BRANCH = $KMS_BRANCH_DEFAULT"

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KMS_BRANCH=$KMS_BRANCH_DEFAULT" --prefix="KMS_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH_DEFAULT" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    source $KIRA_WORKSTATION/start.sh "False"
    break
    ;;

  2*)
    echo "INFO: Starting Advanced Setup..."
    echo "Please select each repo's branches. (Press Enter for default)"
    echo ""

    read -p "Input Sekai Branch (Default: $SEKAI_BRANCH_DEFAULT): " SEKAI_BRANCH
    read -p "Input Kira Frontend Branch (Default: $FRONTEND_BRANCH_DEFAULT): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: $INTERX_BRANCH_DEFAULT): " INTERX_BRANCH
    read -p "Input KMS Branch (Default: $KMS_BRANCH_DEFAULT): " KMS_BRANCH

    [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT
    [ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT
    [ -z "$KMS_BRANCH" ] && KMS_BRANCH=$KMS_BRANCH_DEFAULT
    [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH=$INTERX_BRANCH_DEFAULT

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KMS_BRANCH=$KMS_BRANCH" --prefix="KMS_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True

    source $KIRA_WORKSTATION/start.sh "False"

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
