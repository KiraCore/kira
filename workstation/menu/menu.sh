#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e
set +x

SKIP_SELECTION="$1" && [ -z "$SKIP_SELECTION" ] && SKIP_SELECTION="true"

if [ "${SKIP_SELECTION,,}" == "false" ] || ( [ "$(globGet INFRA_MODE)" != "validator" ] && [ "$(globGet INFRA_MODE)" != "sentry" ] && [ "$(globGet INFRA_MODE)" != "seed" ] ) ; then
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
        INFRA_MODE="validator"
        #setGlobEnv INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO
        break
        ;;
      2*)
        echo "INFO: Starting Sentry Mode Deployment..."
        INFRA_MODE="sentry"
        #setGlobEnv INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO
        break
        ;;
      3*)
        echo "INFO: Starting Seed Mode Deployment..."
        INFRA_MODE="seed"
        #setGlobEnv INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE"
        globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO
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

loadGlobEnvs
globSet SNAPSHOT_TARGET "$(globGet INFRA_MODE)"
globSet FIREWALL_ZONE "$(globGet INFRA_MODE)"
#globSet INFRA_MODE "$INFRA_MODE"

source $KIRA_MANAGER/menu/submenu.sh
