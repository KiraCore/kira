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

while :; do
  read -p "Input option: " KEY

  echo ""

  case ${KEY,,} in
  1*)
    echo "INFO: Starting Quick Setup..."
    echo "SEKAI_BRANCH = v0.1.7.4"
    echo "FRONTEND_BRANCH = dev"
    echo "INTERX_BRANCH = KIP_31"
    echo "KMS_BRANCH = develop"

    SEKAI_BRANCH="v0.1.7.4"
    FRONTEND_BRANCH="dev"
    INTERX_BRANCH="KIP_31"
    KMS_BRANCH="develop"

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KMS_BRANCH=$KMS_BRANCH" --prefix="KMS_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    source $KIRA_WORKSTATION/start.sh "False"
    break
    ;;

  2*)
    echo "INFO: Starting Advanced Setup..."
    echo "Please select each repo's branches. (Press Enter for default)"
    echo ""

    read -p "Input Sekai Branch (Default: v0.1.7.4): " SEKAI_BRANCH
    read -p "Input Kira Frontend Branch (Default: dev): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: KIP_31): " INTERX_BRANCH
    read -p "Input KMS Branch (Default: develop): " KMS_BRANCH

    [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH="v0.1.7.4"
    [ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH="dev"
    [ -z "$KMS_BRANCH" ] && KMS_BRANCH="develop"
    [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH="KIP_31"

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
    ;;
  esac
done
