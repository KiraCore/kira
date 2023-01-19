#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart SETUP_NETWORKING
PORTS=($(globGet CUSTOM_INTERX_PORT) $(globGet CUSTOM_RPC_PORT) $(globGet CUSTOM_P2P_PORT) $(globGet CUSTOM_PROMETHEUS_PORT) $(globGet CUSTOM_GRPC_PORT))
PORTS_EXPOSURE=$(globGet PORTS_EXPOSURE)
FIREWALL_ZONE=$(globGet FIREWALL_ZONE)
IFACE=$(globGet IFACE)
PRIORITY_WHITELIST="-32000"
PRIORITY_BLACKLIST="-32000"
PRIORITY_MIN="-31000"
PRIORITY_MAX="32767"
ALL_IP="0.0.0.0/0"

PUBLIC_IP=$(timeout 60 bash -c ". /etc/profile && getPublicIp" 2> /dev/null || echo "")
LOCAL_IP=$(timeout 60 bash -c ". /etc/profile && getLocalIp '$IFACE'" 2> /dev/null || echo "0.0.0.0")

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: NETWORKING $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| FIREWALL ENABLED: $(globGet FIREWALL_ENABLED)"
echoWarn "|    FIREWALL ZONE: $FIREWALL_ZONE"
echoWarn "|   PORTS EXPOSURE: $PORTS_EXPOSURE"
echoWarn "|        PUBLIC IP: $PUBLIC_IP"
echoWarn "|         LOCAL IP: $LOCAL_IP"
echoWarn "------------------------------------------------"
set -x

# if [ "$(globGet FIREWALL_ENABLED)" != "true" ] ; then
#     echoInfo "INFO: Firewall configuraiton will be skipped"
#     exit 0
# fi

echoInfo "INFO: Stopping docker & restaring firewall..."
$KIRA_MANAGER/kira/containers-pkill.sh "true" "stop"
$KIRA_COMMON/docker-stop.sh || echoWarn "WARNING: Failed to stop docker service"

service dbus start || echoWarn "WARNING: Failed to start dbus service"
timeout 60 systemctl restart firewalld || echoWarn "WARNING: Failed to restart firewalld service"

echoInfo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"
firewall-cmd --get-zones
firewall-cmd --permanent --zone=public --change-interface=$(globGet IFACE)

echoInfo "INFO: firewalld cleanup"
DEFAULT_ZONES=(validator sentry seed)
for zone in "${DEFAULT_ZONES[@]}" ; do
    firewall-cmd --permanent --zone=$zone --remove-interface=docker0 || echoInfo "INFO: Failed to remove docker0 interface from $zone zone"
    firewall-cmd --permanent --delete-zone=$zone || echoInfo "INFO: Failed to delete $zone zone"
done

firewall-cmd --permanent --new-zone=$FIREWALL_ZONE || echoInfo "INFO: Failed to create $FIREWALL_ZONE already exists"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --change-interface=$(globGet IFACE)
firewall-cmd --permanent --zone=$FIREWALL_ZONE --change-interface=$(globGet IFACE)
firewall-cmd --permanent --zone=$FIREWALL_ZONE --set-target=default
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-interface=docker0
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source="$ALL_IP"

DEFAULT_INTERX_PORT="$(globGet DEFAULT_INTERX_PORT)"
DEFAULT_P2P_PORT="$(globGet DEFAULT_P2P_PORT)"
DEFAULT_RPC_PORT="$(globGet DEFAULT_RPC_PORT)"
DEFAULT_GRPC_PORT="$(globGet DEFAULT_GRPC_PORT)"
DEFAULT_PROMETHEUS_PORT="$(globGet DEFAULT_PROMETHEUS_PORT)"

for i in {100..108} ; do
    # INTERX
    TMP_PORT=$((DEFAULT_INTERX_PORT + $i))
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$TMP_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$TMP_PORT/tcp
    [[ ! " ${PORTS[@]} " =~ " ${TMP_PORT} " ]] && PORTS+=($TMP_PORT)

    # P2P
    TMP_PORT=$((DEFAULT_P2P_PORT + $i))
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$TMP_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$TMP_PORT/tcp
    [[ ! " ${PORTS[@]} " =~ " ${TMP_PORT} " ]] && PORTS+=($TMP_PORT)

    # RPC
    TMP_PORT=$((DEFAULT_RPC_PORT + $i))
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$TMP_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$TMP_PORT/tcp
    [[ ! " ${PORTS[@]} " =~ " ${TMP_PORT} " ]] && PORTS+=($TMP_PORT)

    # GRPC
    TMP_PORT=$((DEFAULT_GRPC_PORT + $i))
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$TMP_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$TMP_PORT/tcp
    [[ ! " ${PORTS[@]} " =~ " ${TMP_PORT} " ]] && PORTS+=($TMP_PORT)

    # PROMETHEUS
    TMP_PORT=$((DEFAULT_PROMETHEUS_PORT + $i))
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$TMP_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$TMP_PORT/tcp
    [[ ! " ${PORTS[@]} " =~ " ${TMP_PORT} " ]] && PORTS+=($TMP_PORT)

    [ "$(isWSL)" != "true" ] && break
done

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_INTERX_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_INTERX_PORT/tcp
CUSTOM_INTERX_PORT="$(globGet CUSTOM_INTERX_PORT)"
if [ "$CUSTOM_INTERX_PORT" != "$DEFAULT_INTERX_PORT" ] && ($(isPort "$CUSTOM_INTERX_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$CUSTOM_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$CUSTOM_INTERX_PORT/tcp
fi

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_P2P_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_P2P_PORT/tcp
CUSTOM_P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
if [ "$CUSTOM_P2P_PORT" != "$DEFAULT_P2P_PORT" ] && ($(isPort "$CUSTOM_P2P_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$CUSTOM_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$CUSTOM_P2P_PORT/tcp
fi

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_RPC_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_RPC_PORT/tcp
CUSTOM_RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
if [ "$CUSTOM_RPC_PORT" != "$DEFAULT_RPC_PORT" ] && ($(isPort "$CUSTOM_RPC_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$CUSTOM_RPC_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$CUSTOM_RPC_PORT/tcp
fi

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_GRPC_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_GRPC_PORT/tcp
CUSTOM_GRPC_PORT="$(globGet CUSTOM_GRPC_PORT)"
if [ "$CUSTOM_GRPC_PORT" != "$DEFAULT_GRPC_PORT" ] && ($(isPort "$CUSTOM_GRPC_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$CUSTOM_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$CUSTOM_GRPC_PORT/tcp
fi

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_PROMETHEUS_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_PROMETHEUS_PORT/tcp
CUSTOM_PROMETHEUS_PORT="$(globGet CUSTOM_PROMETHEUS_PORT)"
if [ "$CUSTOM_PROMETHEUS_PORT" != "$DEFAULT_PROMETHEUS_PORT" ] && ($(isPort "$CUSTOM_PROMETHEUS_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$CUSTOM_PROMETHEUS_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$CUSTOM_PROMETHEUS_PORT/tcp
fi

# required for SSH
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=22/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=22/tcp

DEFAULT_SSH_PORT="$(globGet DEFAULT_SSH_PORT)"
if [ "$DEFAULT_SSH_PORT" != "22" ] && ($(isPort "$DEFAULT_SSH_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_SSH_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_SSH_PORT/tcp
fi

# required for DNS service
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=53/udp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=53/udp

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=10.0.0.0/8 masquerade"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=192.168.0.0/16 masquerade"

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"22\" protocol=\"tcp\" accept"

echoInfo "INFO: Setting up '$FIREWALL_ZONE' zone networking for '$(globGet IFACE)' interface & stopping docker before changes are applied..."

for PORT in "${PORTS[@]}" ; do
    if [ "${PORTS_EXPOSURE,,}" == "disabled" ] ; then
        echoInfo "INFO: Disabling public access to the port $PORT, networking is tured off ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    elif [ "${PORTS_EXPOSURE,,}" == "enabled" ] ; then
        echoInfo "INFO: Enabling public access to the port $PORT, networking is tured on ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
        continue 
    elif [ "${PORTS_EXPOSURE,,}" != "custom" ] ; then
        echoErr "WRROR: Unknown ports exposure type '$PORTS_EXPOSURE'"
        exit 1
    fi

    echoInfo "INFO: Custom global rules will be enforced for the port $PORT"

    PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
    WHITELIST="$PORT_CFG_DIR/whitelist"
    BLACKLIST="$PORT_CFG_DIR/blacklist"
    mkdir -p "$PORT_CFG_DIR"
    touch "$WHITELIST" "$BLACKLIST"

    PORT_EXPOSURE=$(globGet "PORT_EXPOSURE_${PORT}")
    [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"

    if [ "${PORT_EXPOSURE,,}" == "disabled" ] ; then
        echoInfo "INFO: Disabling public access to the port $PORT..."
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    elif [ "${PORT_EXPOSURE,,}" == "enabled" ] ; then
        echoInfo "INFO: Enabling public access to the port $PORT..."
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
        continue 
    elif [ "${PORT_EXPOSURE,,}" == "whitelist" ] ; then
        echoInfo "INFO: Custom whitelist rules will be applied to the port $PORT..."
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        while read ip ; do
            [ -z "$ip" ] && continue # only display non-empty lines
            echoInfo "INFO: Whitelisting address ${ip}..."
            firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_WHITELIST family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" accept"
        done < $WHITELIST
    elif [ "${PORT_EXPOSURE,,}" == "blacklist" ] ; then
        echoInfo "INFO: Custom blacklist rules will be applied to the port $PORT..."
        while read ip ; do
            [ -z "$ip" ] && continue # only display non-empty lines
            echoInfo "INFO: Blacklisting address ${ip}..."
            firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_BLACKLIST family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" reject"
        done < $BLACKLIST
    else
        echoWarn "WARNING: Rule '$PORT_EXPOSURE' is unrecognized and can NOT be applied to the port $PORT, disabling port access"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    fi

    if [ ! -z "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "0.0.0.0" ] ; then
        echoInfo "INFO: Whitleisting (self) PUBLIC IP $PUBLIC_IP"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_WHITELIST family=\"ipv4\" source address=\"$PUBLIC_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
    fi
    
    if [ ! -z "$LOCAL_IP" ] && [ "$LOCAL_IP" != "0.0.0.0" ] ; then
        echoInfo "INFO: Whitleisting (self) LOCAL IP $LOCAL_IP"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_WHITELIST family=\"ipv4\" source address=\"$LOCAL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
    fi
done

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"10.0.0.0/8\" port port=\"1-65535\" protocol=\"tcp\" accept"
# firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"172.16.0.0/12\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"192.168.0.0/16\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"0.0.0.0\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"127.0.0.1\" port port=\"1-65535\" protocol=\"tcp\" accept"

firewall-cmd --get-zones
firewall-cmd --zone=$FIREWALL_ZONE --list-all || echoInfo "INFO: Failed to list '$FIREWALL_ZONE' zone"
firewall-cmd --zone=trusted --list-all 
firewall-cmd --zone=public --list-all
firewall-cmd --reload
firewall-cmd --complete-reload
firewall-cmd --set-default-zone=$FIREWALL_ZONE # can't set the zone before reloading first
firewall-cmd --check-config || echoInfo "INFO: Failed to check firewall config"

echoInfo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"

echoInfo "INFO: Restarting firewalld service"
systemctl restart firewalld

echoInfo "INFO: All iptables rules"
iptables -L -v -n || echoWarn "WARNING: Failed to list iptable rules"

echoInfo "INFO: Current '$FIREWALL_ZONE' zone rules"
firewall-cmd --list-ports
firewall-cmd --get-active-zones
firewall-cmd --zone=$FIREWALL_ZONE --list-all

echoInfo "INFO: Stopping docker, then removing and recreating all docker-created network interfaces"
$KIRA_MANAGER/launch/update-ifaces.sh

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: NETWORKING SCRIPT                  |"
echoWarn "|  ELAPSED: $(timerSpan SETUP_NETWORKING) seconds"
echoWarn "------------------------------------------------"
set -x