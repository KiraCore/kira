#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/seeds-edit.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# e.g.: $KIRA_MANAGER/kira/seeds-edit.sh --destination="$PUBLIC_SEEDS" --target="Seed Nodes"

destination=""
target=""
getArgs "$1" "$2" --gargs_throw=false --gargs_verbose="true"

if [ -z "$target" ] || [ ! -f "$destination" ] ; then
    echoErr "ERROR: Can't edit node adresses, the target was not specified of file '$destination' does NOT exist"
    exit 1
fi

target=$(toUpper "$target")
START_TIME_SEED_EDITOR="$(date -u +%s)"
WHITESPACE="                          "
FILE="/tmp/seeds.tmp"

CHAIN_ID=$(jsonQuickParse "chain_id" $LOCAL_GENESIS_PATH || echo "$NETWORK_NAME")

rm -f $FILE
touch "$FILE" "$destination"
cat $destination > $FILE
sort -u $FILE -o $FILE

OLD_FILE_HASH=$(md5 "$FILE")

while : ; do

    NEW_FILE_HASH=$(md5 "$FILE")

    ################################################################################################
    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA $(toUpper "$target") EDITOR $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(strFixC "TARGET FILE: $destination" 78)|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    # echoC ";whi" "|  NR. |                       <NODE-ID>@<IP>:<PORT>                           |"
    echoC ";whi" "|  NR. |                                                                       |"

    i=0
    while read addr ; do
        [ -z "$addr" ] && continue # only display non-empty lines
        i=$((i + 1))
                 
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
                 
        declare -l p1="${addrArr1[0]}"
        declare -l p2="${addrArr2[0]}"
        declare -l p3="${addrArr2[1]}"

        p2=$(resolveDNS $p2)
        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId=""
        PING_TIME=$(tmconnect handshake --address="$p1@$p2:$p3" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "0")
        (! $(isNaturalNumber $PING_TIME)) && PING_TIME=0

        colIndx="whi"
        colAddr="whi"
        colPing="gre"
        colStat="gre"
        colNetw="whi"
        
        if [[ $PING_TIME -ge 1 ]] ; then
            PING="$PING_TIME ms"
            STATUS="ONLINE"
            [[ $PING_TIME -ge 1000 ]] && colPing="yel"
            NETW=$(tmconnect network --address="$p2:$p3" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
        elif [[ $PING_TIME -le 0 ]] ; then
            PING="???"
            NETW="???"
            STATUS="OFFLINE"
            colStat="red"
            colPing="bla"
            colNetw="bla"
        fi

        if [ "$NETW" == "???" ] ; then
            olNetw="bla"
        elif [ "$NETW" != "$CHAIN_ID" ] ; then
            colNetw="red"
        fi
        
        ($(isNullOrWhitespaces "$NETW")) && NETW="???" && colNetw="bla"

        INDX=$(strFixR "${i}. " 6)
        ADDR=$(strFixC "$p1@$p2:$p3" 71)
        PING="$(strFixC "$PING" 11)"
        STAT="$(strFixC "$STATUS" 16)"
        NETW="$(strFixC "$NETW" 16)"

        echoC ";whi" "|$(echoC "res;$colIndx" "$INDX")|$(echoC "res;$colAddr" "$ADDR")|"
        echoC ";whi" "|      | PING: $(echoC "res;$colPing" "$PING")| STATUS: $(echoC "res;$colStat" "$STAT")| NETWORK: $(echoC "res;$colNetw" "$NETW")|"

    done < $FILE

    colA="whi"
    colD="whi"
    colW="whi"
    selA="a"
    selD="d"
    selW="w"
    OPTION_ADD=$(strFixL " [A] Add New Address" 25)
    OPTION_DEL=$(strFixL " [D] Delete Address" 25)
    OPTION_WPE=$(strFixL " [W] Wipe All Adresses" 26)

    colS="gre"
    colR="whi"
    colX="whi"
    selS="s"
    selR="r"
    selX="x"
    OPTION_SVE=$(strFixL " [S] Save Changes" 25)
    OPTION_REF=$(strFixL " [R] Refresh" 25)
    OPTION_EXT=$(strFixL " [X] Exit" 26)

    if [[ $i -le 0 ]] ; then
        selD=""
        selW=""
        colD="bla"
        colW="bla"
        echoC ";whi" "|      |$(echoC "res;red" "$(strFixC "NO ADDRESSES WERE FOUND" 71)")|"
    fi

    if [ "$NEW_FILE_HASH" == "$OLD_FILE_HASH" ] ; then
        colS="bla"
        selS=""
    fi

    echoC ";whi" "|$(echoC "res;bla" "$(strFixC "-" 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;$colA" "$OPTION_ADD")|$(echoC "res;$colD" "$OPTION_DEL")|$(echoC "res;$colW" "$OPTION_WPE")|"
    echoC ";whi" "|$(echoC "res;$colS" "$OPTION_SVE")|$(echoC "res;$colR" "$OPTION_REF")|$(echoC "res;$colX" "$OPTION_EXT")|"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    pressToContinue --timeout=86400 --cursor=false "$colA" "$colD" "$selW" "$selS" "$selR" "$selX" && VSEL="$(globGet OPTION)" || VSEL="w"

    if [ "$VSEL" == "r" ] ; then
        echoInfo "INFO: Rrefreshing node list..." 
        continue
    elif [ "$VSEL" == "e" ] ; then
        exit 0
    elif [ "$VSEL" == "w" ] ; then
        echoInfo "INFO: Removing all addresses from the list" 
        echo -n "" > $FILE 
        continue
    elif [ "$VSEL" == "s" ] ; then
        echoInfo "INFO: Saving unique changes to $destination..."
        cp -a -v -f "$FILE" "$destination"
        cat $destination > $FILE
        OLD_FILE_HASH=$(md5 "$FILE")
        continue
    fi

    echoInfo "INFO: ${target} should have address format <node-id>@<dns>:<port> but you can also input standalone DNS or IP addresses"
    echoNErr "Input comma separated list of ${target}: " && read ADDR_LIST
    [ -z "$ADDR_LIST" ] && echoWarn "WARNING: No addresses were specified, try again" && continue

    i=0

    for addr in $(echo $ADDR_LIST | sed "s/,/ /g") ; do
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        p1=$(toLower "${addrArr1[0]}")
        p2=$(toLower "${addrArr2[0]}")
        p3=$(toLower "${addrArr2[1]}")

        ($(isDnsOrIp "$addr")) && dns="$addr" || dns=""
        ($(isNodeId "$addr")) && nodeId="$addr" || nodeId=""

        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId="$nodeId"
        ($(isDnsOrIp "$p2")) && dns="$p2" || dns="$dns"
        ($(isPort "$p3")) && port="$p3" || port=""

        if [ "$VSEL" == "d" ] ; then
            if [ "${dns}" == "${addr}" ] || [ "${nodeId}" == "${addr}" ] ; then
                echoInfo "INFO: Removing last occurence of '$addr' address from the ${target} list..."
                setLastLineBySubStrOrAppend "$addr" "" $FILE
                i=$((i + 1))
                continue
            fi
        fi

        # in case of missing node id
        ($(isDnsOrIp "$p1")) && dnsStandalone="$p1" || dnsStandalone="" 
        ($(isPort "$p2")) && portStandalone="$p2" || portStandalone=""

        ($(isIp "$dns")) && ($(isPublicIp "$dns")) && echoWarn "WARNING: Address '$dns' is an IP address of a public, internet network"
        ($(isIp "$dns")) && (! $(isPublicIp "$dns")) && echoWarn "WARNING: Address '$dns' is an IP address of a local, private network"

        # if detected missing node id, try to recover it
        DETECTED_NODES=""
        if [ ! -z "${dnsStandalone}" ] ; then
            dns="$dnsStandalone"
            echoWarn "WARNING: '$addr' is NOT a valid ${target} address but a standalone IP or DNS"
            echoNC "bli;whi" "\nDo you want to scan '$dnsStandalone' and attempt to acquire a public node id? (y/n): " && pressToContinue y n && YNO="$(globGet OPTION)"
            [ "$YNO" != "y" ] && echoInfo "INFO: Address '$addr' will NOT be added to ${target} list" && continue

            [ ! -z "$portStandalone" ] && [ "${portStandalone}" != "$(globGet DEFAULT_RPC_PORT)" ] && [ "${portStandalone}" != "$(globGet DEFAULT_INTERX_PORT)" ] && port="$portStandalone"
            [ ! -z "$port" ] && if ! timeout 1 nc -z $dns $port ; then
                echoWarn "WARNING: Port '$port' is not accessible or not defined, attempting discovery..." 
                port=""
            fi

            KIRA_SEED_P2P_PORT=$(globGet KIRA_SEED_P2P_PORT)
            KIRA_SENTRY_P2P_PORT=$(globGet KIRA_SENTRY_P2P_PORT)
            KIRA_VALIDATOR_P2P_PORT=$(globGet KIRA_VALIDATOR_P2P_PORT)
            CUSTOM_P2P_PORT=$(globGet CUSTOM_P2P_PORT)
            seed_node_id=$(tmconnect id --address="$dns:$KIRA_SEED_P2P_PORT" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
            sentry_node_id=$(tmconnect id --address="$dns:$KIRA_SENTRY_P2P_PORT" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
            validator_node_id=$(tmconnect id --address="$dns:$KIRA_VALIDATOR_P2P_PORT" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
            custom_node_id=$(tmconnect id --address="$dns:$CUSTOM_P2P_PORT" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")

            if ($(isNodeId "$seed_node_id")) && timeout 1 nc -z $dns $KIRA_SEED_P2P_PORT ; then 
                tmp_addr="${seed_node_id}@${dns}:$KIRA_SEED_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_SEED_P2P_PORT is exposed" ; 
            else 
                echoInfo "INFO: Port $KIRA_SEED_P2P_PORT is NOT accepting P2P connections" ; 
            fi

            if ($(isNodeId "$sentry_node_id")) && timeout 1 nc -z $dns $KIRA_SENTRY_P2P_PORT ; then 
                tmp_addr="${sentry_node_id}@${dns}:$KIRA_SENTRY_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_SENTRY_P2P_PORT is exposed" ; 
            else 
                echoInfo "INFO: Port $KIRA_SENTRY_P2P_PORT is NOT accepting P2P connections" ; 
            fi

            if ($(isNodeId "$validator_node_id")) && timeout 1 nc -z $dns $KIRA_VALIDATOR_P2P_PORT ; then 
                tmp_addr="${validator_node_id}@${dns}:$KIRA_VALIDATOR_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_VALIDATOR_P2P_PORT is exposed" ; 
            else 
                echoInfo "INFO: Port $KIRA_VALIDATOR_P2P_PORT is NOT accepting P2P connections" ; 
            fi

            if ($(isNodeId "$custom_node_id")) && timeout 1 nc -z $dns $KIRA_VALIDATOR_P2P_PORT ; then 
                tmp_addr="${custom_node_id}@${dns}:$CUSTOM_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $CUSTOM_P2P_PORT is exposed" ; 
            else 
                echoInfo "INFO: Port $CUSTOM_P2P_PORT is NOT accepting P2P connections" ; 
            fi
        else
            DETECTED_NODES="${nodeId}@${dns}:${port}"
        fi

        [ -z "$DETECTED_NODES" ] && echoErr "ERROR: '$addr' is NOT valid or NOT exposed ${target} address" && continue
        
        for nodeAddress in $(echo $DETECTED_NODES | sed "s/,/ /g") ; do
            nodeAddress=$(echo "$nodeAddress" | xargs) # trim whitespace characters
            addrArr1=( $(echo $nodeAddress | tr "@" "\n") )
            addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
            nodeId=$(toLower "${addrArr1[0]}")
               dns=$(toLower "${addrArr2[0]}")
              port=$(toLower "${addrArr2[1]}")

            if  ($(isNodeId "$nodeId")) && ($(isDnsOrIp "$dns")) && ($(isPort "$port")) ; then
                if [ "$VSEL" == "a" ] ; then
                    echoNC "bli;whi" "\nAre you absolutely sure you want to add '$nodeAddress' to ${target} list? (y/n): " && pressToContinue y n && YNO=$(toLower "$(globGet OPTION)")
                    [ "$YNO" != "y" ] && echoInfo "INFO: Address '$nodeAddress' will NOT be added to ${target} list" && continue
                    
                    echoInfo "INFO: Adding address to the ${target} list..."
                    setLastLineBySubStrOrAppend "$nodeId" "$nodeAddress" $FILE
                else
                    echoInfo "INFO: Removing last address from the ${target} list..."
                    setLastLineBySubStrOrAppend "$nodeId" "" $files
                fi
                i=$((i + 1))
            else
                echoWarn "WARNING: '$nodeAddress' is NOT a valid ${target} address"
                continue
            fi
        done
    done

    sort -u $FILE -o $FILE
    [ "$VSEL" == "a" ] && echoInfo "INFO: Total of $i ${target} addresses were added"
    [ "$VSEL" == "d" ] && echoInfo "INFO: Total of $i ${target} addresses were removed"
done
