#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/mnemonic-select.sh" && rm -f $FILE && touch $FILE && nano $FILE && chmod 555 $FILE
set +x

INFRA_MODE=$(globGet INFRA_MODE)
MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS

while (! $(isMnemonic "$MASTER_MNEMONIC")) ; do

    set +x
    MASTER_MNEMONIC=$(getVar MASTER_MNEMONIC "$MNEMONICS")
    NODE_ID=$(getVar "$(toUpper "$INFRA_MODE")_NODE_ID" "$MNEMONICS")
    [ -z "$NODE_ID" ] && NODE_ID="???"

        clear
        cSubCnt=57
        echoC ";whi" " =============================================================================="
     echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "SECRETS MANAGMENT TOOL, KM $KIRA_SETUP_VER" 78)")|"
        echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
        echoC ";whi" "| Secrets Direcotry: $(strFixL "$KIRA_SECRETS" $cSubCnt) |"
        echoC ";whi" "| Keystore Location: $(strFixL "$MNEMONICS" $cSubCnt) |"
        echoC ";whi" "| $(strFixL "${INFRA_MODE^} Node ID" 19): $(strFixL "$NODE_ID" 55) |"
     echoC "sto;whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
        echoC ";whi" "|$(strFixL " [G] | Generate new master mnemonic and DELETE all old secrets" 78)|"
    if (! $(isMnemonic "$MASTER_MNEMONIC")) ; then
        echoC ";whi" "|$(strFixL " [M] | Modify existing master mnemonic and DELETE all old secrets" 78)|"
        echoC ";whi" "|$(strFixL " [V] | Display existing master mnemonic from keystore" 78)|"
    fi
        echoC ";whi" "|$(strFixL " [X] | Exit without making changes" 78)|"

    setterm -cursor off
    if [(! $(isMnemonic "$MASTER_MNEMONIC")) ; then
        pressToContinue g m v x && KEY=$(globGet OPTION)
    else
        pressToContinue g x && KEY=$(globGet OPTION)
    fi
    setterm -cursor on

    if [ "$KEY" == "x" ] ; then
        break
    elif [ "$KEY" == "g" ] ; then
        echoNLog "Press [Y]es to wipe secrets dir. & generate new secrets or [N]o to cancel: " && pressToContinue y n && KEY=$(globGet OPTION)
        if [ "$KEY" == "y" ] ; then
            rm -rfv "$KIRA_SECRETS"
            mkdir -p "$KIRA_SECRETS"
            setVar MASTER_MNEMONIC "autogen" "$MNEMONICS" 1> /dev/null
        else
            continue
        fi
    elif [ "$KEY" == "g" ] ; then
        echoNLog "Press [Y]es to wipe secrets dir. & define new secrets or [N]o to cancel: " && pressToContinue y n && KEY=$(globGet OPTION)
        if [ "$KEY" == "y" ] ; then
            while (! $(isMnemonic "$MASTER_MNEMONIC")) ; do
                echoNLog "Input 24 whitespace-separated bip39 words or press [ENTER] to autogen.: " && read MASTER_MNEMONIC
                MASTER_MNEMONIC=$(echo "$MASTER_MNEMONIC" | xargs 2> /dev/null || echo -n "")
                MASTER_MNEMONIC=$(echo ${MASTER_MNEMONIC//,/ })
                if [ -z $MASTER_MNEMONIC ] ; then
                    rm -rfv "$KIRA_SECRETS"
                    mkdir -p "$KIRA_SECRETS"
                    setVar MASTER_MNEMONIC "autogen" "$MNEMONICS" 1> /dev/null
                    break
                elif ($(isMnemonic "$MASTER_MNEMONIC")) ; then
                    rm -rfv "$KIRA_SECRETS"
                    mkdir -p "$KIRA_SECRETS"
                    setVar MASTER_MNEMONIC "$MASTER_MNEMONIC" "$MNEMONICS" 1> /dev/null
                    break
                fi
        else
            continue
        fi
    elif [ "$KEY" == "v" ] ; then
        clear
        IFS=" "
        read -ra arr <<< "$MASTER_MNEMONIC"
        for i in "${!arr[@]}"; do
            echoC ";whi" "$((i+1)). ${arr[i]}"
        done
        echoNLog "Press any key to continue: " && pressToContinue ""
    fi

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e
done