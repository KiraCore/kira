#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/seeds-edit.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

DESTINATION=$1
TARGET=$2
START_TIME_SEED_EDITOR="$(date -u +%s)"
WHITESPACE="                          "
FILE="/tmp/seeds.tmp"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: SEED EDITOR $KIRA_SETUP_VER                |"
echoWarn "|-----------------------------------------------"
echoWarn "|  TARGET FILE: $DESTINATION"
echoWarn "| CONTENT TYPE: ${TARGET^^}"
echoWarn "------------------------------------------------"

rm -f $FILE
touch "$FILE" "$DESTINATION"
cat $DESTINATION > $FILE

while : ; do
    echo -e "INFO: Listing all ${TARGET^^}, please wait...\n"
    i=0
    echo -e "\e[0m\e[33;1m-------------------------------------------------------------------"
                    echo "| ID |  STATUS |  PING  |                 ADDRESS                 @"
                 echo -e "|----|---------|--------|------------------------------------------\e[0m"
    while read addr ; do
        [ -z "$addr" ] && continue # only display non-empty lines
        i=$((i + 1))
                 
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
                 
        p1=${addrArr1[0],,}
        p2=${addrArr2[0],,}
        p3=${addrArr2[1],,}

        p2=$(resolveDNS $p2)
        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId=""
        PING_TIME=$(tmconnect handshake --address="$p1@$p2:$p3" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "0")
        (! $(isNaturalNumber $PING_TIME)) && PING_TIME=0

        if [[ $PING_TIME -ge 1 ]] && [[ $PING_TIME -le 999 ]] ; then
            PING="$PING_TIME ms"
            STATUS="ONLINE" 
        elif [[ $PING_TIME -le 0 ]] ; then
            PING="???? "
            STATUS="OFFLINE" 
        else
            PING="> 1 s"
            STATUS="ONLINE" 
        fi
             
        INDEX_TMP=$(echo "${WHITESPACE}${i}" | tail -c 4)
        PING_TMP=$(echo "${WHITESPACE}${PING}" | tail -c 7)
        STATUS_TMP="${STATUS}${WHITESPACE}"
        TG="\e[0m\e[33;1m|\e[32;1m"
        TR="\e[0m\e[33;1m|\e[31;1m"
         
        [ "${STATUS,,}" == "online" ] && echo -e "\e[0m\e[32;1m${TG}${INDEX_TMP} $TG ${STATUS_TMP:0:7} $TG ${PING_TMP} $TG $addr\e[0m"
        [ "${STATUS,,}" == "offline" ] && echo -e "\e[0m\e[31;1m${TR}${INDEX_TMP} $TR ${STATUS_TMP:0:7} $TR ${PING_TMP} $TR $addr\e[0m"
    done < $FILE
    echo -e "\e[0m\e[33;1m------------------------------------------------------------------\e[0m\n"
    echoInfo "INFO: All $i ${TARGET^^} were displayed"
    echoInfo "INFO: Remeber to [S]ave changes after you finish!"
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(a|d|w|r|s|e)$ ]] ; do echoNErr "Choose to [A]dd, [D]elete, [W]ipe, [R]efresh, [S]ave changes to the $TARGET list or [E]xit: " && read -d'' -s -n1 SELECT && echo ""; done
    [ "${SELECT,,}" == "r" ] && continue
    [ "${SELECT,,}" == "e" ] && exit 0

    if [ "${SELECT,,}" == "s" ] ; then
        FILE_HASH=$(md5 "$FILE")
        DESTINATION_HASH=$(md5 "$DESTINATION")

        if [ "$FILE_HASH" != "$DESTINATION_HASH" ] ; then
            echoInfo "INFO: Saving unique changes to $DESTINATION..."
            cp -a -v -f "$FILE" "$DESTINATION"
            cat $DESTINATION > $FILE
        else
            echoInfo "INFO: Nothing to save, NO changes were made"
        fi

        continue
    fi
             
    [ "${SELECT,,}" == "w" ] && echoInfo "INFO: All ${TARGET^^} were removed" && echo -n "" > $FILE && continue
    echoInfo "INFO: ${TARGET^^} should have a format of <node-id>@<dns>:<port> but you can also input standalone DNS or IP addresses"
    echoNErr "Input comma separated list of ${TARGET^^}: " && read ADDR_LIST
    [ -z "$ADDR_LIST" ] && echoWarn "WARNING: No addresses were specified, try again" && continue

    i=0
    for addr in $(echo $ADDR_LIST | sed "s/,/ /g") ; do
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        p1=${addrArr1[0],,}
        p2=${addrArr2[0],,}
        p3=${addrArr2[1],,}

        ($(isDnsOrIp "$addr")) && dns="$addr" || dns=""
        ($(isNodeId "$addr")) && nodeId="$addr" || nodeId=""

        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId="$nodeId"
        ($(isDnsOrIp "$p2")) && dns="$p2" || dns="$dns"
        ($(isPort "$p3")) && port="$p3" || port=""

        if [ "${SELECT,,}" == "d" ] ; then
            if [ "${dns}" == "${addr}" ] || [ "${nodeId}" == "${addr}" ] ; then
                echoInfo "INFO: Removing all '$addr' address from the ${TARGET^^} list..."
                CDHelper text lineswap --insert="" --regex="$addr" --path=$FILE --append-if-found-not=True --silent=True
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
            echoWarn "WARNING: '$addr' is NOT a valid ${TARGET^^} address but a standalone IP or DNS"
            SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echoNErr "Do you want to scan '$dnsStandalone' and attempt to acquire a public node id? (y/n): " && read -d'' -s -n1 SVAL && echo ""; done
            [ "${SVAL,,}" != "y" ] && echoInfo "INFO: Address '$addr' will NOT be added to ${TARGET^^} list" && continue

            [ ! -z "$portStandalone" ] && [ "${portStandalone}" != "$DEFAULT_RPC_PORT" ] && [ "${portStandalone}" != "$DEFAULT_INTERX_PORT" ] && port="$portStandalone"
            [ ! -z "$port" ] && if ! timeout 1 nc -z $dns $port ; then
                echoWarn "WARNING: Port '$port' is not accessible or not defined, attempting discovery..." 
                port=""
            fi

            seed_node_id=$(tmconnect id --address="$dns:$KIRA_SEED_P2P_PORT" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            sentry_node_id=$(tmconnect id --address="$dns:$KIRA_SENTRY_P2P_PORT" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            validator_node_id=$(tmconnect id --address="$dns:$KIRA_VALIDATOR_P2P_PORT" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")

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
        else
            DETECTED_NODES="${nodeId}@${dns}:${port}"
        fi

        [ -z "$DETECTED_NODES" ] && echoErr "ERROR: '$addr' is NOT valid or NOT exposed ${TARGET^^} address" && continue
        
        for nodeAddress in $(echo $DETECTED_NODES | sed "s/,/ /g") ; do
            nodeAddress=$(echo "$nodeAddress" | xargs) # trim whitespace characters
            addrArr1=( $(echo $nodeAddress | tr "@" "\n") )
            addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
            nodeId=${addrArr1[0],,}
            dns=${addrArr2[0],,}
            port=${addrArr2[1],,}

            if  ($(isNodeId "$nodeId")) && ($(isDnsOrIp "$dns")) && ($(isPort "$port")) ; then
                if [ "${SELECT,,}" == "a" ] ; then
                    SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echoNErr "Are you absolutely sure you want to add '$nodeAddress' to ${TARGET^^} list? (y/n): " && read -d'' -s -n1 SVAL && echo ""; done
                    [ "${SVAL,,}" != "y" ] && echoInfo "INFO: Address '$nodeAddress' will NOT be added to ${TARGET^^} list" && continue
                    
                    echoInfo "INFO: Adding address to the ${TARGET^^} list..."
                    CDHelper text lineswap --insert="$nodeAddress" --regex="$nodeId" --path=$FILE --append-if-found-not=True --silent=True
                else
                    echoInfo "INFO: Removing address from the ${TARGET^^} list..."
                    CDHelper text lineswap --insert="" --regex="$nodeId" --path=$FILE --append-if-found-not=True --silent=True
                fi
                i=$((i + 1))
            else
                echoWarn "WARNING: '$nodeAddress' is NOT a valid ${TARGET^^} address"
                continue
            fi
        done
    done

    sort -u $FILE -o $FILE
    [ "${SELECT,,}" == "a" ] && echoInfo "INFO: Total of $i ${TARGET^^} addresses were added"
    [ "${SELECT,,}" == "d" ] && echoInfo "INFO: Total of $i ${TARGET^^} addresses were removed"
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| CLOSED: SEED EDITOR                          |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME_SEED_EDITOR)) seconds"
echoWarn "------------------------------------------------"
set -x

