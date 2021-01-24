#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e

START_TIME_NETWORKING="$(date -u +%s)"
PORTS=($KIRA_FRONTEND_PORT $KIRA_SENTRY_GRPC_PORT $KIRA_INTERX_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_RPC_PORT $KIRA_PRIV_SENTRY_P2P_PORT)
[ -z "$PORTS_EXPOSURE" ] && PORTS_EXPOSURE="enabled" # default networking state is all ports enabled to the public internet

set +x
echo "------------------------------------------------"
echo "| STARTED: NETWORKING                          |"
echo "|-----------------------------------------------"
echo "| DEPLOYMENT MODE: $INFRA_MODE"
echo "------------------------------------------------"
set -x

echo "INFO: Ensuring UFW rules persistence"
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

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echo "INFO: Setting up demo mode networking for $IFACE interface & stopping docker before changes are applied..."
    ZONE="demo"
    firewall-cmd --permanent --delete-zone=$ZONE || echo "INFO: Failed to delete $ZONE zone"
    firewall-cmd --permanent --new-zone=$ZONE || echo "INFO: Failed to create $ZONE already exists"
    firewall-cmd --permanent --change-interface=$IFACE
    firewall-cmd --permanent --zone=$ZONE --change-interface=$IFACE
    firewall-cmd --permanent --zone=$ZONE --set-target=default
    firewall-cmd --permanent --zone=$ZONE --add-interface=docker0

    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=22/tcp

    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_REGISTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_VALIDATOR_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SENTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SERVICE_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"22\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_INTERX_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_P2P_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_RPC_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_GRPC_PORT\" protocol=\"tcp\" accept"

elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    echo "INFO: Setting up sentry mode networking..."
    ZONE="sentry"

elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    echo "INFO: Setting up validator mode networking for $IFACE interface & stopping docker before changes are applied..."
    ZONE="validator"
    firewall-cmd --permanent --delete-zone=$ZONE || echo "INFO: Failed to delete $ZONE zone"
    firewall-cmd --permanent --new-zone=$ZONE || echo "INFO: Failed to create $ZONE already exists"
    firewall-cmd --permanent --change-interface=$IFACE
    firewall-cmd --permanent --zone=$ZONE --change-interface=$IFACE
    firewall-cmd --permanent --zone=$ZONE --set-target=default
    firewall-cmd --permanent --zone=$ZONE --add-interface=docker0

    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_PRIV_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=$ZONE --add-port=22/tcp

    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_REGISTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_VALIDATOR_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SENTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SERVICE_SUBNET masquerade"
    firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"22\" protocol=\"tcp\" accept"
    
    for PORT in "${PORTS[@]}" ; do
        PORT_EXPOSURE="PORT_EXPOSURE_$PORT" && PORT_EXPOSURE="${!PORT_EXPOSURE}"
        [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"
        if [ "${PORTS_EXPOSURE,,}" == "disabled" ] ; then
            echo "INFO: Disabling public access to the port $PORT, networking is tured off ($PORTS_EXPOSURE)"
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" reject"
            continue
        elif [ "${PORTS_EXPOSURE,,}" == "enabled" ] ; then
            echo "INFO: Enabling public access to the port $PORT, networking is tured on ($PORTS_EXPOSURE)"
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" accept"
            continue 
        else
            echo "INFO: Custom global rules will be enforced for the port $PORT"
        fi

        PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
        WHITELIST="$PORT_CFG_DIR/whitelist"
        BLACKLIST="$PORT_CFG_DIR/blacklist"
        mkdir -p "$PORT_CFG_DIR"
        touch "$WHITELIST" "$BLACKLIST"

        
        if [ "${PORT_EXPOSURE,,}" == "disabled" ] ; then
            echo "INFO: Disabling public access to the port $PORT..."
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" reject"
            continue
        elif [ "${PORT_EXPOSURE,,}" == "enabled" ] ; then
            echo "INFO: Enabling public access to the port $PORT..."
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" accept"
            continue 
        elif [ "${PORT_EXPOSURE,,}" == "whitelist" ] ; then
            echo "INFO: Custom whitelist rules will be applied to the port $PORT..."
            while read ip; do
                [ -z "$ip" ] && continue # only display non-empty lines
                i=$((i + 1))
                echo "INFO: Whitelisting address ${ip}..."
                firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" accept"
            done < $WHITELIST
        elif [ "${PORT_EXPOSURE,,}" == "enabled" ] ; then
            echo "INFO: Custom blacklist rules will be applied to the port $PORT..."
            echo "INFO: Whitelisting all IP addresses other then the ones defined in the blacklist..."
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" accept"
            while read ip; do
                [ -z "$ip" ] && continue # only display non-empty lines
                i=$((i + 1))
                echo "INFO: Blacklisting address ${ip}..."
                firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"$ip\" port port=\"$PORT\" protocol=\"tcp\" reject"
            done < $BLACKLIST
        else
            echo "WARNING: Rule '$PORT_EXPOSURE' is unrecognized and can NOT be applied to the port $PORT, disabling port access"
            firewall-cmd --permanent --zone=$ZONE --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$PORT\" protocol=\"tcp\" reject"
            continue
        fi
    done
else
    echo "INFO: Unrecognized networking mode '$INFRA_MODE'"
    exit 1
fi

firewall-cmd --reload
firewall-cmd --get-zones
firewall-cmd --zone=$ZONE --list-all
firewall-cmd --zone=trusted --list-all 
firewall-cmd --zone=public --list-all 
firewall-cmd --set-default-zone=$ZONE
firewall-cmd --complete-reload
firewall-cmd --check-config || echo "INFO: Failed to check firewall config"

echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"

# restart the services
systemctl restart firewalld
systemctl restart docker

echo "INFO: Restarting docker..."
systemctl restart NetworkManager docker || echo "WARNING: Failed to restart network manager"

echo "------------------------------------------------"
echo "| FINISHED: NETWORKING SCRIPT                  |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_NETWORKING)) seconds"
echo "------------------------------------------------"
