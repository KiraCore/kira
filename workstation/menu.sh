#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e
set +x

SKIP_SELECTION=$1
[ -z "$SKIP_SELECTION" ] && SKIP_SELECTION="true"

if [ "${SKIP_SELECTION,,}" == "false" ] || ( [ "${INFRA_MODE,,}" != "validator" ] && [ "${INFRA_MODE,,}" != "sentry" ] && [ "${INFRA_MODE,,}" != "seed" ] ) ; then
    printf "\033c"
    printWidth=47
    echo -e "\e[31;1m-------------------------------------------------"
    displayAlign center $printWidth "KIRA DEPLOYMENT TOOL $KIRA_SETUP_VER"
    displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "|-----------------------------------------------|"
    displayAlign center $printWidth "Select Deployment Mode"
    displayAlign left $printWidth " [1] | Validator Mode"
    displayAlign left $printWidth " [2] | Sentry Mode"
    displayAlign left $printWidth " [3] | Seed Mode"
    echo "|-----------------------------------------------|"
    displayAlign left $printWidth " [X] | Exit"
    echo -e "-------------------------------------------------\e[0m\c"
    echo ""
     
    while :; do
      read -n1 -p "Input option: " KEY
      echo ""
      
      case ${KEY,,} in
      1*)
        echo "INFO: Starting Validator Node Deployment..."
        CDHelper text lineswap --insert="INFRA_MODE=validator" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="FIREWALL_ZONE=validator" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
        break
        ;;
      2*)
        echo "INFO: Starting Sentry Mode Deployment..."
        CDHelper text lineswap --insert="INFRA_MODE=sentry" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="FIREWALL_ZONE=sentry" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
        break
        ;;
      3*)
        echo "INFO: Starting Seed Mode Deployment..."
        CDHelper text lineswap --insert="INFRA_MODE=seed" --prefix="INFRA_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="FIREWALL_ZONE=seed" --prefix="FIREWALL_ZONE=" --path=$ETC_PROFILE --append-if-found-not=True # firewall zone
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
fi

source $KIRA_MANAGER/submenu.sh
