#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/node-type-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set +x

function cleanup() {
    setterm -cursor on
    trap - SIGINT || :
    echoNInfo "\n\nINFO: Exiting script...\n"
    exit 130
}

while :; do
    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "SELECT TYPE OF THE KIRA NODE TO DEPLOY, KM $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
              echoC ";whi" "| [1] |$(strFixC "Validator Mode" 18):$(strFixC "Operator node with aggressive prunning" 52) |"
              echoC ";whi" "| [2] |$(strFixC "Sentry Mode" 18):$(strFixC "Full archival node and DDOS protection" 52) |"
              echoC ";whi" "| [3] |$(strFixC "Seed Mode" 18):$(strFixC "Connector enabling network discovery " 52) |"
    echoC ";whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
    echoC ";whi" "| [X] |$(strFixC "Exit" 18):$(strFixC " " 52) |"
    echoNC ";whi" " ------------------------------------------------------------------------------"
    
  setterm -cursor off && trap cleanup SIGINT
  pressToContinue 1 2 3 x && VSEL=$(toLower "$(globGet OPTION)") || VSEL="r"
  setterm -cursor on && trap - SIGINT || :
  
  clear
  [ "$VSEL" != "r" ] && echoInfo "INFO: Option '$VSEL' was selected, processing request..."

  case "$VSEL" in
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
