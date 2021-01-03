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

set +x
clear

printWidth=47
echo -e "\e[31;1m-------------------------------------------------"
displayAlign center $printWidth "$title"
displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
echo -e "|-----------------------------------------------|"
echo -e "| Network Interface: $IFACE (default)" 
echo -e "|-----------------------------------------------|"
displayAlign left $printWidth " [1] | Quick Setup"
displayAlign left $printWidth " [2] | Advanced Setup"
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
    echo "SEKAI branch: $SEKAI_BRANCH_DEFAULT"
    echo "FRONTEND branch: $FRONTEND_BRANCH_DEFAULT"
    echo "INTERX branch: $INTERX_BRANCH_DEFAULT"
    echo "NETWORK interface: $IFACE"

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH_DEFAULT" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True

    $KIRA_MANAGER/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
    set -x
    $KIRA_MANAGER/kira/kira.sh
    exit 0
    ;;

  2*)
    echo "INFO: Starting Advanced Setup..."
    echo -en "\e[31;1mPlease select each repo's branches. (Press Enter for default)\e[0m" && echo ""

    read -p "Input SEKAI Branch (Default: $SEKAI_BRANCH_DEFAULT): " SEKAI_BRANCH
    read -p "Input FRONTEND Branch (Default: $FRONTEND_BRANCH_DEFAULT): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: $INTERX_BRANCH_DEFAULT): " INTERX_BRANCH

    echo -en "\e[31;1mPlease select your default internet connected network interface:\e[0m" && echo ""

    ifaces=$(ifconfig | cut -d ' ' -f1| tr ':' '\n' | awk NF)
    
    i=-1
    for f in $ifaces ; do
        i=$((i + 1))
        echo "[$i] $f"
    done
   
    OPTION=""
    while : ; do
        read -p "Input interface number 0-$i (Default: $IFACE): " OPTION
        [ -z "$OPTION" ] && break
        [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
    done

    if [ ! -z "$OPTION" ] ; then
        IFACE=${ifaces[$OPTION]}
    fi

    [ -z $IFACE ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
    [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT
    [ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT
    [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH=$INTERX_BRANCH_DEFAULT

    echo -en "\e[31;1mINFO: SEKAI branch '$SEKAI_BRANCH' was selected\e[0m" && echo ""
    echo -en "\e[31;1mINFO: FRONTEND branch '$FRONTEND_BRANCH' was selected\e[0m" && echo ""
    echo -en "\e[31;1mINFO: INTERX branch '$INTERX_BRANCH' was selected\e[0m" && echo ""
    echo -en "\e[31;1mINFO: NETWORK interface '$IFACE' was selected\e[0m" && echo ""
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""

    CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True

    $KIRA_MANAGER/start.sh "False" || FAILED="true"
    [ "${FAILED,,}" == "true" ] && echo "ERROR: Failed to launch the infrastructure"
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
