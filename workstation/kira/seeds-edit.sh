#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/seeds-edit.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

DESTINATION=$1
TARGET=$2
START_TIME_SEED_EDITOR="$(date -u +%s)"
WHITESPACE="                          "
FILE="/tmp/seeds.tmp"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: SEED EDITOR v0.2.3.2                |"
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
    echo -e "\e[0m\e[33;1m-----------------------------------------------------------"
                    echo "| ID. |  STATUS |                 ADDRESS                 @"
                 echo -e "|-----|---------|------------------------------------------\e[0m"
    while read addr ; do
        [ -z "$addr" ] && continue # only display non-empty lines
        i=$((i + 1))
                 
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
                 
        p1=${addrArr1[0],,}
        p2=${addrArr2[0],,}
        p3=${addrArr2[1],,}

        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId=""
        ($(isDnsOrIp "$p2")) && dns="$p2" || dns=""
        if ! timeout 1 nc -z $p2 $p3 &>/dev/null ; then STATUS="OFFLINE" ; else STATUS="ONLINE" ; fi
        [ "${STATUS,,}" == "online" ] && if ! timeout 1 nc -z $dns $p3 &>/dev/null ; then STATUS="OFFLINE" ; fi
             
        INDEX_TMP=$(echo "${WHITESPACE}${i}." | tail -c 4)
        STATUS_TMP="${STATUS}${WHITESPACE}"
        TG="\e[0m\e[33;1m|\e[32;1m"
        TR="\e[0m\e[33;1m|\e[31;1m"
         
        [ "${STATUS,,}" == "online" ] && echo -e "\e[0m\e[32;1m$TG ${INDEX_TMP} $TG ${STATUS_TMP:0:7} $TG $addr\e[0m"
        [ "${STATUS,,}" == "offline" ] && echo -e "\e[0m\e[31;1m$TR ${INDEX_TMP} $TR ${STATUS_TMP:0:7} $TR $addr\e[0m"
    done < $FILE
    echo -e "\e[0m\e[33;1m-----------------------------------------------------------\e[0m\n"
    echo "INFO: All $i ${TARGET^^} were displayed"
         
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(a|d|w|r|s|e)$ ]] ; do echoNErr "Choose to [A]dd, [D]elete, [W]ipe, [R]efresh, [S]ave changes to the $TARGET list or [E]xit: " && read -d'' -s -n1 SELECT && echo ""; done
    [ "${SELECT,,}" == "r" ] && continue
    [ "${SELECT,,}" == "e" ] && exit 0

    if [ "${SELECT,,}" == "s" ] ; then
        FILE_HASH=$(sha256sum "$FILE" | awk '{ print $1 }' || echo -n "")
        DESTINATION_HASH=$(sha256sum "$DESTINATION" | awk '{ print $1 }' || echo -n "")

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

            seed_node_id=$(timeout 1 curl -f "$dns:$DEFAULT_INTERX_PORT/download/seed_node_id" || echo -n "")
            sentry_node_id=$(timeout 1 curl -f "$dns:$DEFAULT_INTERX_PORT/download/sentry_node_id" || echo -n "")
            ( ! $(isNodeId "$sentry_node_id")) && sentry_node_id=$(timeout 1 curl ${dnsStandalone}:11000/api/kira/status 2>/dev/null | jsonQuickParse "id" 2>/dev/null || echo -n "")
            ( ! $(isNodeId "$sentry_node_id")) && sentry_node_id=$(timeout 1 curl ${dnsStandalone}:$DEFAULT_RPC_PORT/status 2>/dev/null | jsonQuickParse "id" 2>/dev/null || echo -n "")
            priv_sentry_node_id=$(timeout 1 curl -f "$dns:$DEFAULT_INTERX_PORT/download/priv_sentry_node_id" || echo -n "")

            if ($(isNodeId "$seed_node_id")) && timeout 1 nc -z $dns $KIRA_SEED_P2P_PORT ; then 
                tmp_addr="${seed_node_id}@${dns}:$KIRA_SEED_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_SEED_P2P_PORT is exposed by '$dns'" ; 
            else 
                echoInfo "INFO: Port $KIRA_SEED_P2P_PORT is not exposed as '$dns'" ; 
            fi

            if ($(isNodeId "$sentry_node_id")) && timeout 1 nc -z $dns $KIRA_SENTRY_P2P_PORT ; then 
                tmp_addr="${sentry_node_id}@${dns}:$KIRA_SENTRY_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_SENTRY_P2P_PORT is exposed as '$dns'" ; 
            else 
                echoInfo "INFO: Port $KIRA_SENTRY_P2P_PORT is not exposed by '$dns'" ; 
            fi

            if ($(isNodeId "$priv_sentry_node_id")) && timeout 1 nc -z $dns $KIRA_PRIV_SENTRY_P2P_PORT ; then 
                tmp_addr="${priv_sentry_node_id}@${dns}:$KIRA_PRIV_SENTRY_P2P_PORT"
                [ -z "$DETECTED_NODES" ] && DETECTED_NODES="$tmp_addr" || DETECTED_NODES="${DETECTED_NODES},$tmp_addr"
                echoInfo "INFO: Port $KIRA_PRIV_SENTRY_P2P_PORT is exposed as '$dns'" ; 
            else 
                echoInfo "INFO: Port $KIRA_PRIV_SENTRY_P2P_PORT is not exposed by '$dns'" ; 
            fi
        else
            DETECTED_NODES="${nodeId}@${dns}:${port}"
        fi

        [ -z "$DETECTED_NODES" ] && echoErr "ERROR: '$addr' is NOT valid or not exposed ${TARGET^^} address" && continue
        
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

