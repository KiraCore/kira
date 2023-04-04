#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/mnemonic-select.sh" && rm -f $FILE && touch $FILE && nano $FILE && chmod 555 $FILE

# Force console colour to be black and text gray
tput setab 0
tput setaf 7

INFRA_MODE="$(globGet INFRA_MODE)"
MNEMONICS="$KIRA_SECRETS/mnemonics.env"
touch $MNEMONICS

while : ; do
    selG="g"
    selM="m"
    selV="v"
    selX="x"
    OPTION_GENE="$(strFixL " [G] | Generate new master mnemonic and DELETE all secrets " 78 )"
    OPTION_MODI="$(strFixL " [M] | Modify master mnemonic and DELETE all secrets " 78 )"
    OPTION_VIEW="$(strFixL " [V] | Display master mnemonic from keystore " 78 )"
    OPTION_EXIT="$(strFixL " [X] | Exit " 78 )"

    NODE_ID="$(tryGetVar "$(toUpper "$INFRA_MODE")_NODE_ID" "$MNEMONICS")"
    [ -z "$NODE_ID" ] && NODE_ID="???"

        set +x && printf "\033c" && clear
        echoC ";whi" " =============================================================================="
     echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA SECRETS MANAGMER $KIRA_SETUP_VER" 78)")|"
        echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
        echoC ";whi" "|$(strFixR "$(toCapital "$INFRA_MODE") Node ID" 18): $(strFixL "$NODE_ID" 57) |"

        if [ "$INFRA_MODE" == "validator" ] ; then
            VALIDATOR_ADDR=$(validator-key-gen --mnemonic="$(tryGetVar VALIDATOR_ADDR_MNEMONIC "$MNEMONICS")" --accadr=true --prefix=kira --path="44'/118'/0'/0/0" || echo "")
            echoC ";whi" "|$(strFixR "$(toCapital "$INFRA_MODE") Addres" 18): $(strFixL "$VALIDATOR_ADDR" 57) |"
        fi

        echoC ";whi" "| Secrets Direcotry: $(strFixL "$KIRA_SECRETS" 57) |"
        echoC ";whi" "| Keystore Location: $(strFixL "$MNEMONICS" 57) |"
     echoC "sto;whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
        echoC ";whi" "|$OPTION_GENE|"
        echoC ";whi" "|$OPTION_MODI|"
        echoC ";whi" "|$OPTION_VIEW|"
        echoC ";whi" "|$OPTION_EXIT|"
        echoNC ";whi" " ------------------------------------------------------------------------------"

    pressToContinue --cursor=false "$selG" "$selM" "$selV" "$selX" && KEY="$(globGet OPTION)"

    clear
    [ "$KEY" != "r" ] && echoInfo "INFO: Option '$KEY' was selected, processing request..."

    if [ "$KEY" == "x" ] ; then
        break
    elif [ "$KEY" == "g" ] ; then
        echoNLog "Press [Y]es to wipe secrets dir. & generate new secrets or [N]o to cancel: " && pressToContinue y n && KEY=$(globGet OPTION)
        if [ "$KEY" == "y" ] ; then
            rm -rfv "$KIRA_SECRETS" && mkdir -p "$KIRA_SECRETS" && touch "$MNEMONICS"
            setVar MASTER_MNEMONIC "autogen" "$MNEMONICS" 1> /dev/null
        else
            continue
        fi
    elif [ "$KEY" == "m" ] ; then
        echoNLog "Press [Y]es to wipe secrets dir. & define new secrets or [N]o to cancel: " && pressToContinue y n && KEY=$(globGet OPTION)
        if [ "$KEY" == "y" ] ; then
            MASTER_MNEMONIC=""
            while (! $(isMnemonic "$MASTER_MNEMONIC")) ; do
                echoNLog "Input 24 whitespace-separated bip39 words or press [ENTER] to autogen.: " && read MASTER_MNEMONIC
                MASTER_MNEMONIC=$(echo "$MASTER_MNEMONIC" | xargs 2> /dev/null || echo -n "")
                MASTER_MNEMONIC=$(echo ${MASTER_MNEMONIC//,/ })
                if [ -z $MASTER_MNEMONIC ] ; then
                    rm -rfv "$KIRA_SECRETS"
                    mkdir -p "$KIRA_SECRETS" && touch $MNEMONICS
                    setVar MASTER_MNEMONIC "autogen" "$MNEMONICS"
                    break
                elif ($(isMnemonic "$MASTER_MNEMONIC")) ; then
                    rm -rfv "$KIRA_SECRETS"
                    mkdir -p "$KIRA_SECRETS" && touch $MNEMONICS
                    setVar MASTER_MNEMONIC "$MASTER_MNEMONIC" "$MNEMONICS" 1> /dev/null
                    break
                fi
            done
        else
            continue
        fi
    elif [ "$KEY" == "v" ] ; then
        MASTER_MNEMONIC="$(tryGetVar MASTER_MNEMONIC "$MNEMONICS")"
        clear
        IFS=" "
        read -ra arr <<< "$MASTER_MNEMONIC"
        unset IFS
        echoNC ";gre" "Numbered list of your master mnemonic seed words:\n\n"
        i=0
        while [ $i -lt ${#arr[@]} ]; do
            val1="${arr[i]}" && i=$((i+1)) && id1="$i"
            val2="${arr[i]}" && i=$((i+1)) && id2="$i"
            val3="${arr[i]}" && i=$((i+1)) && id3="$i"
            val4="${arr[i]}" && i=$((i+1)) && id4="$i"
            WORD_C1="$(strFixL " $id1. $val1" 18)"
            WORD_C2="$(strFixL " $id2. $val2" 18)"
            WORD_C3="$(strFixL " $id3. $val3" 18)"
            WORD_C4="$(strFixL " $id4. $val4" 18)"
            echoC ";whi" "$WORD_C1|$WORD_C2|$WORD_C3|$WORD_C4"
        done
        echoNC ";gre" "\n\nOrdered list: " && echoNC ";whi" "\n\n$MASTER_MNEMONIC\n\n"
        echoNLog "Press any key to continue..." && pressToContinue ""
    fi

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -e
done