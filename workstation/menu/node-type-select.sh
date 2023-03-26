#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/node-type-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set +x

while :; do
  printf "\033c"
  prtChars=49
  prtCharsSubMax=42
  echo -e "\e[31;1m==================================================="
  echo -e "|$(strFixC "SELECT NODE TYPE TO DEPLY, KM $KIRA_SETUP_VER" $prtChars)"
  echo -e "|-------------------------------------------------|"
  echo -e "| [1] | $(strFixL "Validator Mode" $prtCharsSubMax)|"
  echo -e "| [2] | $(strFixL "Sentry Mode" $prtCharsSubMax)|"
  echo -e "| [3] | $(strFixL "Seed Mode" $prtCharsSubMax)|"
  echo -e "|-------------------------------------------------|"
  echo -e "| [X] | Exit                                      |"
  echo -e "---------------------------------------------------\e[0m\c\n"
  echo ""
  echoNErr "Input option: " && pressToContinue 1 2 3 x && KEY="$(toLower "$(globGet OPTION)")" && echo ""
  
  case "$KEY" in
  1*)
    echo "INFO: Starting Validator Node Deployment..."
    globSet INFRA_MODE "validator"
    break
    ;;
  2*)
    echo "INFO: Starting Sentry Mode Deployment..."
    globSet INFRA_MODE "sentry"
    break
    ;;
  3*)
    echo "INFO: Starting Seed Mode Deployment..."
    globSet INFRA_MODE "seed"
    break
    ;;
  x*)
    break
    ;;
  *)
    echo "Try again."
    sleep 1
    ;;
  esac
done
set -x

# envs must be loaded as they impact custom & default ports
$KIRA_MANAGER/setup/envs.sh
