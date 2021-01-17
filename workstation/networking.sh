#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e

START_TIME_NETWORKING="$(date -u +%s)"

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
    firewall-cmd --permanent --new-zone=demo || echo "INFO: Zone demo already exists"
    firewall-cmd --permanent --change-interface=$IFACE
    firewall-cmd --permanent --zone=demo --change-interface=$IFACE
    firewall-cmd --permanent --zone=demo --set-target=default
    firewall-cmd --permanent --zone=demo --add-interface=docker0

    firewall-cmd --permanent --zone=demo --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=22/tcp

    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_REGISTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_VALIDATOR_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SENTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SERVICE_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"22\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_INTERX_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_P2P_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_RPC_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_GRPC_PORT\" protocol=\"tcp\" accept"

elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    echo "INFO: Setting up sentry mode networking..."

elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    echo "INFO: Setting up validator mode networking for $IFACE interface & stopping docker before changes are applied..."
    firewall-cmd --permanent --new-zone=validator || echo "INFO: Zone validator already exists"
    firewall-cmd --permanent --change-interface=$IFACE
    firewall-cmd --permanent --zone=validator --change-interface=$IFACE
    firewall-cmd --permanent --zone=validator --set-target=default
    firewall-cmd --permanent --zone=validator --add-interface=docker0

    firewall-cmd --permanent --zone=validator --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=validator --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=validator --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=validator --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=validator --add-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=validator --add-port=22/tcp

    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_REGISTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_VALIDATOR_SUBNET masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SENTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SERVICE_SUBNET masquerade"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"22\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_INTERX_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_P2P_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_RPC_PORT\" protocol=\"tcp\" accept"
    firewall-cmd --permanent --zone=validator --add-rich-rule="rule family=\"ipv4\" source address=\"0.0.0.0/8\" port port=\"$KIRA_SENTRY_GRPC_PORT\" protocol=\"tcp\" accept"

else
    echo "INFO: Unrecognized networking mode '$INFRA_MODE'"
    exit 1
fi

firewall-cmd --reload
firewall-cmd --get-zones
firewall-cmd --zone=demo --list-all
firewall-cmd --zone=trusted --list-all 
firewall-cmd --zone=public --list-all 
firewall-cmd --set-default-zone=demo
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
