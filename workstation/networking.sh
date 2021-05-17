#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

START_TIME_NETWORKING="$(date -u +%s)"
PORTS=($KIRA_FRONTEND_PORT $KIRA_SENTRY_GRPC_PORT $KIRA_INTERX_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_RPC_PORT $KIRA_PRIV_SENTRY_P2P_PORT $KIRA_SEED_P2P_PORT $KIRA_VALIDATOR_P2P_PORT)
PRIORITY_WHITELIST="-32000"
PRIORITY_BLACKLIST="-32000"
PRIORITY_MIN="-31000"
PRIORITY_MAX="32767"
ALL_IP="0.0.0.0/0"
PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 | awk -F'"' '{ print $2}' || echo -n "")
( ! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @resolver1.opendns.com myip.opendns.com +time=5 +tries=1 | awk -F'"' '{ print $1}' || echo -n "")
( ! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @ns1.google.com -t txt o-o.myaddr.l.google.com -4 | xargs || echo -n "")
( ! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP=$(timeout 3 curl https://ipinfo.io/ip | xargs || echo -n "")
LOCAL_IP=$(/sbin/ifconfig $IFACE | grep -i mask | awk '{print $2}' | cut -f2 || echo -n "")
( ! $(isDnsOrIp "$LOCAL_IP")) && LOCAL_IP=$(hostname -I | awk '{ print $1}' || echo "0.0.0.0")

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: NETWORKING $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| DEPLOYMENT MODE: $INFRA_MODE"
echoWarn "|   FIREWALL ZONE: $FIREWALL_ZONE"
echoWarn "|  PORTS EXPOSURE: $PORTS_EXPOSURE"
echoWarn "|       PUBLIC IP: $PUBLIC_IP"
echoWarn "|        LOCAL IP: $LOCAL_IP"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Stopping docker & restaring firewall..."
$KIRA_MANAGER/kira/containers-pkill.sh "true" "stop"
$KIRA_SCRIPTS/docker-stop.sh || echoWarn "WARNING: Failed to stop docker service"
timeout 60 systemctl restart firewalld || echoWarn "WARNING: Failed to restart firewalld service"

echoInfo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"
firewall-cmd --get-zones

echoInfo "INFO: firewalld cleanup"
firewall-cmd --permanent --zone=public --change-interface=$IFACE
firewall-cmd --permanent --zone=demo --remove-interface=docker0 || echoInfo "INFO: Failed to remove docker0 interface from demo zone"
firewall-cmd --permanent --zone=validator --remove-interface=docker0 || echoInfo "INFO: Failed to remove docker0 interface from validator zone"
firewall-cmd --permanent --zone=sentry --remove-interface=docker0 || echoInfo "INFO: Failed to remove docker0 interface from validator zone"

firewall-cmd --permanent --delete-zone=demo || echoInfo "INFO: Failed to delete demo zone"
firewall-cmd --permanent --delete-zone=validator || echoInfo "INFO: Failed to delete validator zone"
firewall-cmd --permanent --delete-zone=sentry || echoInfo "INFO: Failed to delete sentry zone"
firewall-cmd --permanent --new-zone=$FIREWALL_ZONE || echoInfo "INFO: Failed to create $FIREWALL_ZONE already exists"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --change-interface=$IFACE
firewall-cmd --permanent --zone=$FIREWALL_ZONE --change-interface=$IFACE
firewall-cmd --permanent --zone=$FIREWALL_ZONE --set-target=default
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-interface=docker0
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source="$ALL_IP"

if [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "demo" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_SEED_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_SEED_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_FRONTEND_PORT/tcp
fi

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_INTERX_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_INTERX_PORT/tcp

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_SENTRY_P2P_PORT/tcp

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_PRIV_SENTRY_P2P_PORT/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_PRIV_SENTRY_P2P_PORT/tcp

if [ "${INFRA_MODE,,}" == "validator" ] && [ "${DEPLOYMENT_MODE,,}" == "minimal" ] ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_VALIDATOR_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_VALIDATOR_P2P_PORT/tcp
else
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_SENTRY_RPC_PORT/tcp

    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$KIRA_SENTRY_GRPC_PORT/tcp
fi

# required for SSH
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=22/tcp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=22/tcp

if [ "$DEFAULT_SSH_PORT" != "22" ] && ($(isPort "$DEFAULT_SSH_PORT")) ; then
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=$DEFAULT_SSH_PORT/tcp
    firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=$DEFAULT_SSH_PORT/tcp
fi

# required for DNS service
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-port=53/udp
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-source-port=53/udp

firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=10.0.0.0/8 masquerade"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=192.168.0.0/16 masquerade"

# required for docker registry
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.16.0.0/12 masquerade"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.27.0.0/16 masquerade"


firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"22\" protocol=\"tcp\" accept"

echoInfo "INFO: Setting up '$FIREWALL_ZONE' zone networking for '$IFACE' interface & stopping docker before changes are applied..."

for PORT in "${PORTS[@]}" ; do
    if [ "${PORTS_EXPOSURE,,}" == "disabled" ] ; then
        echoInfo "INFO: Disabling public access to the port $PORT, networking is tured off ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
        continue
    elif [ "${PORTS_EXPOSURE,,}" == "enabled" ] ; then
        echoInfo "INFO: Enabling public access to the port $PORT, networking is tured on ($PORTS_EXPOSURE)"
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MIN family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" accept"
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

    PORT_EXPOSURE="PORT_EXPOSURE_$PORT" && PORT_EXPOSURE="${!PORT_EXPOSURE}"
    [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"

    if [ "${PORT_EXPOSURE,,}" == "disabled" ] ; then
        echoInfo "INFO: Disabling public access to the port $PORT..."
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
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
        firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"$ALL_IP\" port port=\"$PORT\" protocol=\"tcp\" reject"
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
firewall-cmd --permanent --zone=$FIREWALL_ZONE --add-rich-rule="rule priority=$PRIORITY_MAX family=\"ipv4\" source address=\"172.16.0.0/12\" port port=\"1-65535\" protocol=\"tcp\" accept"
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
$KIRA_MANAGER/scripts/update-ifaces.sh

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: NETWORKING SCRIPT                  |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME_NETWORKING)) seconds"
echoWarn "------------------------------------------------"
set -x