#!/bin/bash

set -e

while :; do
  case "$1" in
  -d | --demo)
    mode="demo"
    title="Demo Mode (local testnet)"
    shift
    ;;
  -f | --full)
    mode="full"
    title="Full Node Mode"
    shift
    ;;
  -v | --validator)
    mode="validator"
    title="Validator Mode"
    shift
    ;;
  -h | --help)
    display_help # Call your function
    # no shifting needed here, we're done.
    exit 0
    ;;
  --) # End of all options
    shift
    break
    ;;
  -*)
    echo "Error: Unknown option: $1" >&2
    exit 1
    ;;
  *) # No more options
    break
    ;;
  esac
done

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
INTERX_BRANCH_DEFAULT="KIP_31"
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
