#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

START_TIME_NETWORKING="$(date -u +%s)"
PORTS=($KIRA_FRONTEND_PORT $KIRA_SENTRY_GRPC_PORT $KIRA_INTERX_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_RPC_PORT $KIRA_PRIV_SENTRY_P2P_PORT)
ZONE=$FIREWALL_ZONE
PRIORITY_WHITELIST="-32000"
PRIORITY_BLACKLIST="-32000"
PRIORITY_MIN="-31000"
PRIORITY_MAX="32767"
ALL_IP="0.0.0.0/0"

set +x
echo "------------------------------------------------"
echo "| STARTED: NETWORKING v0.0.7                   |"
echo "|-----------------------------------------------"
echo "| DEPLOYMENT MODE: $INFRA_MODE"
echo "|   FIREWALL ZONE: $ZONE"
echo "|  PORTS EXPOSURE: $PORTS_EXPOSURE"
echo "------------------------------------------------"
set -x

echo "INFO: Stopping docker & restaring firewall"
systemctl daemon-reload
systemctl stop docker
systemctl restart firewalld

echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"
firewall-cmd --get-zones

echo "INFO: firewalld cleanup"
firewall-cmd --permanent --zone=public --change-interface=$IFACE
firewall-cmd --permanent --zone=demo --remove-interface=docker0 || echo "INFO: Failed to remove docker0 interface from demo zone"
firewall-cmd --permanent --zone=validator --remove-interface=docker0 || echo "INFO: Failed to remove docker0 interface from validator zone"
firewall-cmd --permanent --zone=sentry --remove-interface=docker0 || echo "INFO: Failed to remove docker0 interface from validator zone"

firewall-cmd --permanent --delete-zone=demo || echo "INFO: Failed to delete demo zone"
firewall-cmd --permanent --delete-zone=validator || echo "INFO: Failed to delete validator zone"
firewall-cmd --permanent --delete-zone=sentry || echo "INFO: Failed to delete sentry zone"
firewall-cmd --permanent --new-zone=$ZONE || echo "INFO: Failed to create $ZONE already exists"
firewall-cmd --permanent --zone=$ZONE --change-interface=$IFACE
firewall-cmd --permanent --zone=$ZONE --change-interface=$IFACE
firewall-cmd --permanent --zone=$ZONE --set-target=default
firewall-cmd --permanent --zone=$ZONE --add-interface=docker0
firewall-cmd --permanent --zone=$ZONE --add-source="$ALL_IP"

firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_INTERX_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_PRIV_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_RPC_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_FRONTEND_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-port=22/tcp

firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_INTERX_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_PRIV_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_SENTRY_RPC_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_SENTRY_GRPC_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=$KIRA_FRONTEND_PORT/tcp
firewall-cmd --permanent --zone=$ZONE --add-source-port=22/tcp

firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=10.0.0.0/8 masquerade"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.16.0.0/12 masquerade"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=192.168.0.0/16 masquerade"

firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"22\" protocol=\"tcp\" accept"

echo "INFO: Setting up '$ZONE' zone networking for '$IFACE' interface & stopping docker before changes are applied..."

for PORT in "${PORTS[@]}" ; do
    if [ "${PORTS_EXPOSURE,,}" == "disabled" ] ; then
        echo "INFO: Disabling public access to the port $PORT, networking is tured off ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    elif [ "${PORTS_EXPOSURE,,}" == "enabled" ] ; then
        echo "INFO: Enabling public access to the port $PORT, networking is tured on ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
        continue 
    elif [ "${PORTS_EXPOSURE,,}" != "custom" ] ; then
        echo "INFO: Unknown ports exposure type '$PORTS_EXPOSURE'"
        exit 1
    fi

    echo "INFO: Custom global rules will be enforced for the port $PORT"

    PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
    WHITELIST="$PORT_CFG_DIR/whitelist"
    BLACKLIST="$PORT_CFG_DIR/blacklist"
    mkdir -p "$PORT_CFG_DIR"
    touch "$WHITELIST" "$BLACKLIST"

    PORT_EXPOSURE="PORT_EXPOSURE_$PORT" && PORT_EXPOSURE="${!PORT_EXPOSURE}"
    [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"

    if [ "${PORT_EXPOSURE,,}" == "disabled" ] ; then
        echo "INFO: Disabling public access to the port $PORT..."
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    elif [ "${PORT_EXPOSURE,,}" == "enabled" ] ; then
        echo "INFO: Enabling public access to the port $PORT..."
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
        continue 
    elif [ "${PORT_EXPOSURE,,}" == "whitelist" ] ; then
        echo "INFO: Custom whitelist rules will be applied to the port $PORT..."
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        while read ip; do
            [ -z "$ip" ] && continue # only display non-empty lines
            echo "INFO: Whitelisting address ${ip}..."
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_WHITELIST family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" accept"
        done < $WHITELIST
    elif [ "${PORT_EXPOSURE,,}" == "blacklist" ] ; then
        echo "INFO: Custom blacklist rules will be applied to the port $PORT..."
        while read ip; do
            [ -z "$ip" ] && continue # only display non-empty lines
            echo "INFO: Blacklisting address ${ip}..."
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_BLACKLIST family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" reject"
        done < $BLACKLIST
    else
        echo "WARNING: Rule '$PORT_EXPOSURE' is unrecognized and can NOT be applied to the port $PORT, disabling port access"
        firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    fi
done
      
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"10.0.0.0/8\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"172.16.0.0/12\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"192.168.0.0/16\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"0.0.0.0\" port port=\"1-65535\" protocol=\"tcp\" accept"
firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"127.0.0.1\" port port=\"1-65535\" protocol=\"tcp\" accept"

firewall-cmd --get-zones
firewall-cmd --zone=$ZONE --list-all || echo "INFO: Failed to list '$ZONE' zone"
firewall-cmd --zone=trusted --list-all 
firewall-cmd --zone=public --list-all
firewall-cmd --reload
firewall-cmd --complete-reload
firewall-cmd --set-default-zone=$ZONE # can't set the zone before reloading first
firewall-cmd --reload
firewall-cmd --complete-reload
firewall-cmd --check-config || echo "INFO: Failed to check firewall config"

echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"

# restart the services
systemctl restart firewalld
systemctl restart docker

echo "INFO: Restarting docker..."
systemctl restart NetworkManager docker || echo "WARNING: Failed to restart network manager"

echo "INFO: All iptables rules"
iptables -L -v -n

echo "INFO: Current '$ZONE' zone rules"
firewall-cmd --list-ports
firewall-cmd --get-active-zones
firewall-cmd --zone=$ZONE --list-all

set +x
echo "------------------------------------------------"
echo "| FINISHED: NETWORKING SCRIPT                  |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_NETWORKING)) seconds"
echo "------------------------------------------------"
set -x