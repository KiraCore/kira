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

if [ "${INFRA_MODE,,}" == "local" ] ; then
    IFace=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
    echo "INFO: Setting up demo mode networking for $IFace interface & stopping docker before changes are applied..."
    systemctl daemon-reload
    systemctl stop docker
    systemctl restart firewalld

    #firewall-cmd --permanent --new-zone=trusted || echo "INFO: Zone trusted already exists"
    #firewall-cmd --zone=trusted --add-interface=docker0 # apply imediately
    #firewall-cmd --zone=trusted --add-interface=docker_gwbridge
    #firewall-cmd --permanent --zone=trusted --add-interface=docker0 # apply permanently
    #firewall-cmd --permanent --zone=trusted --add-interface=docker_gwbridge
#
    #firewall-cmd --zone=trusted --add-masquerade 
    #firewall-cmd --permanent --zone=trusted --add-masquerade 
#
    #echo "INFO: Adding brige interfaces to trusted zones"
    #for f in $(ifconfig | cut -d ' ' -f1| tr ':' '\n' | awk NF) ; do
    #    [[ $f != *"br-"* ]] && continue
    #    echo "INFO: Adding $f interface to trusted zone"
    #    firewall-cmd --zone=trusted --add-interface=$f
    #    firewall-cmd --permanent --zone=trusted --add-interface=$f
    #done
#
    #firewall-cmd --permanent --new-zone=public || echo "INFO: Zone public already exists"
    #firewall-cmd --zone=public --add-masquerade 
    #firewall-cmd --permanent --zone=public --add-masquerade 
    
    #firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 3 -i docker0 -j ACCEPT
    # firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 0 -i docker0 -j ACCEPT
    
    echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"

    firewall-cmd --permanent --new-zone=demo || echo "INFO: Zone demo already exists"
    firewall-cmd --permanent --change-interface=$IFace
    firewall-cmd --permanent --zone=demo --change-interface=$IFace
    #firewall-cmd --permanent --zone=demo --remove-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=22/tcp
    firewall-cmd --permanent --zone=demo --set-target=REJECT


    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=172.17.0.0/16 masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=172.18.0.0/16 masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_REGISTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_VALIDATOR_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SENTRY_SUBNET masquerade"
    firewall-cmd --permanent --zone=demo --add-rich-rule="rule family=\"ipv4\" source address=$KIRA_SERVICE_SUBNET masquerade"

    firewall-cmd --reload
    firewall-cmd --get-zones
    firewall-cmd --zone=demo --list-all
    firewall-cmd --zone=trusted --list-all 
    firewall-cmd --set-default-zone=demo
    firewall-cmd --complete-reload
    firewall-cmd --check-config || echo "INFO: Failed to check firewall config"

    echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"

    # restart the services
    systemctl restart firewalld
    systemctl restart docker

    echo "INFO: Restarting docker..."
    systemctl restart NetworkManager docker || echo "WARNING: Failed to restart network manager"

elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    echo "INFO: Setting up sentry mode networking..."

elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    echo "INFO: Setting up validator mode networking..."
else
    echo "INFO: Unrecognized networking mode '$INFRA_MODE'"
    exit 1
fi

echo "------------------------------------------------"
echo "| FINISHED: NETWORKING SCRIPT                  |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_NETWORKING)) seconds"
echo "------------------------------------------------"
