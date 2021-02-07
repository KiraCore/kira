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
echo "------------------------------------------------"
echo "| STARTED: SEED EDITOR v0.0.1                  |"
echo "|-----------------------------------------------"
echo "|  TARGET FILE: $DESTINATION"
echo "| CONTENT TYPE: $TARGET"
echo "------------------------------------------------"

rm -f $FILE
touch "$FILE" "$DESTINATION"

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
        
        nodeId="" && [[ "$p1" =~ ^[a-f0-9]{40}$ ]] && nodeId="$p1"
        dns="" && [[ "$(echo $p2 | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)')" == "$p2" ]] && dns="$p2" # DNS regex
        [ -z "$dns" ] && [[ $p2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && dns="$p2" # IP is fine too

        if ! timeout 1 ping -c1 $dns &>/dev/null ; then STATUS="OFFLINE" ; else STATUS="ONLINE" ; fi
             
        INDEX_TMP=$(echo "${WHITESPACE}${i}." | tail -c 4)
        STATUS_TMP="${STATUS}${WHITESPACE}"
        TG="\e[0m\e[33;1m|\e[32;1m"
        TR="\e[0m\e[33;1m|\e[31;1m"
         
        [ "${STATUS,,}" == "online" ] && echo -e "\e[0m\e[32;1m$TG ${INDEX_TMP} $TG ${STATUS_TMP:0:7} $TG $addr\e[0m"
        [ "${STATUS,,}" == "offline" ] && echo -e "\e[0m\e[31;1m$TR ${INDEX_TMP} $TR ${STATUS_TMP:0:7} $TR $addr\e[0m"
    done < $DESTINATION
    echo -e "\e[0m\e[33;1m-----------------------------------------------------------\e[0m\n"
    echo "INFO: All $i ${TARGET^^} were displayed"
         
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(a|d|w|r|s)$ ]] ; do echoNErr "Choose to [A]dd, [D]elete, [W]ipe, [R]efresh or [S]kip making changes to the $TARGET list: " && read -d'' -s -n1 SELECT && echo ""; done
    [ "${SELECT,,}" == "r" ] && continue
    [ "${SELECT,,}" == "s" ] && break
             
    if [ "${SELECT,,}" == "w" ] ; then
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(y|n)$ ]] ; do echoNErr "Are you absolutely sure you want to DELETE all ${TARGET^^}? (y/n): " && read -d'' -s -n1 SELECT && echo ""; done
        echo "INFO: You selected NOT do wipe all ${TARGET^^}"
        [ "${SELECT,,}" != "y" ] && break
        echo "INFO: You selected to delete all ${TARGET^^}"
        echo "" > $FILE
        continue
    fi
       
    echo ""
    [ "${OPTION,,}" == "s" ] && echo "INFO: ${TARGET^^} should have a format of <node-id>@<dns>:<port>"
    echo -en "\e[31;1mInput comma separated list of $TARGET: \e[0m" && read ADDR_LIST

    if [ -z "$ADDR_LIST" ] ; then
        echoInfo "INFO: No addresses were specified, try again"
        continue
    fi

    i=0
    for addr in $(echo $ADDR_LIST | sed "s/,/ /g") ; do
        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        p1=${addrArr1[0],,}
        p2=${addrArr2[0],,}
        p3=${addrArr2[1],,}
        
        nodeId="" && [[ "$p1" =~ ^[a-f0-9]{40}$ ]] && nodeId="$p1"
        dns="" && [[ "$(echo $p2 | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)')" == "$p2" ]] && dns="$p2" # DNS regex
        [ -z "$dns" ] && [[ $p2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && dns="$p2" # IP is fine too
        # port must be a number within the range of <1,65535>
        port="" && ( [[ $p3 =~ ^[0-9]+$ ]] && (($p3 > 0 || $p3 < 65536)) ) && port="$p3"

        # in case of missing node id
        dnsStandalone="" && [[ "$(echo $p1 | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)')" == "$p1" ]] && dnsStandalone="$p1" # DNS regex
        [ -z "$dnsStandalone" ] && [[ $p1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && dnsStandalone="$p1" # IP is fine too
        # portStandalone must be a number within the range of <1,65535>
        portStandalone="" && ( [[ $p2 =~ ^[0-9]+$ ]] && (($p2 > 0 || $p2 < 65536)) ) && portStandalone="$p2"

        # if detected missing node id, try to recover it
        if [ ! -z "${dnsStandalone}" ] ; then
            echoWarn "WARNING:'$addr' is NOT a valid $TARGET address but a standalone IP or DNS"
            SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echo -en "\e[31;1mDo you want to scan '$dnsStandalone' and attempt to acquire a public node id? (y/n): \e[0m\c" && read -d'' -s -n1 SVAL && echo ""; done
            [ "${SVAL,,}" != "y" ] && echo "INFO: Address '$addr' will NOT be added to ${TARGET^^} list" && continue

            # try to get node ID from the RPC or INTERX
            nodeId=$(timeout 1 curl ${dnsStandalone}:11000/api/kira/status 2>/dev/null | jq -r '.node_info.id' 2>/dev/null || echo "")
            ( [ -z "$nodeId" ] || [ "${nodeId,,}" == "null" ] ) && nodeId=$(timeout 1 curl ${dnsStandalone}:$DEFAULT_RPC_PORT/status 2>/dev/null | jq -r '.node_info.id' 2>/dev/null || echo "")
            [ ! -z "$portStandalone" ] && [ "${portStandalone}" != "$DEFAULT_RPC_PORT" ] && [ "${portStandalone}" != "$DEFAULT_INTERX_PORT" ] && port="$portStandalone"
            [ -z "$port" ] && port=$DEFAULT_P2P_PORT
            
            [[ "$nodeId" =~ ^[a-f0-9]{40}$ ]] && nodeId="$nodeId" || nodeId=""
            dns=$dnsStandalone
            addr="${nodeId}@${dns}:${port}"
        fi
        
        nodeAddress="${nodeId}@${dns}:${port}"
        if [ ! -z "$nodeId" ] && [ ! -z "$dns" ]  && [ ! -z "$port" ] ; then
            echo "INFO: SUCCESS, '$nodeAddress' is a valid $TARGET address!"
            if [ "${SELECT,,}" == "a" ] ; then
                if ! timeout 1 ping -c1 $dns &>/dev/null ; then 
                    echo "WARNING: Node with address '$dns' is NOT reachable"
                    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(y|n)$ ]] ; do echo -en "\e[31;1mAre you absolutely sure you want to add '$dns' to ${TARGET^^} list? (y/n): \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
                    [ "${SELECT,,}" != "y" ] && echo "INFO: Address '$addr' will NOT be added to ${TARGET^^} list" && continue
                fi
                echo "INFO: Adding address to the $TARGET list..."
                CDHelper text lineswap --insert="$nodeAddress" --regex="$nodeId" --path=$FILE --append-if-found-not=True --silent=True
            else
                echo "INFO: Removing address from the $TARGET list..."
                CDHelper text lineswap --insert="" --regex="$nodeId" --path=$FILE --append-if-found-not=True --silent=True
            fi
            i=$((i + 1))
        else
            echo "INFO: FAILURE, '$addr' is NOT a valid $TARGET address"
            continue
        fi
    done
    echo "INFO: Saving unique changes to $FILE..."
    sort -u $FILE -o $FILE
    [ "${SELECT,,}" == "a" ] && echo "INFO: Total of $i $TARGET addresses were added"
    [ "${SELECT,,}" == "d" ] && echo "INFO: Total of $i $TARGET addresses were removed"

    cp -a -v -f "$FILE" "$DESTINATION"
done

set +x
echo "------------------------------------------------"
echo "| CLOSED: SEED EDITOR                          |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_SEED_EDITOR)) seconds"
echo "------------------------------------------------"
set -x

