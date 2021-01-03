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
    echo "INFO: Setting up demo mode networking & stopping docker before changes are applied..."
    systemctl daemon-reload
    systemctl stop docker
    systemctl restart firewalld
 
    # NOTE:
    # All rules should be persisted in /etc/firewalld/direct.xml
    #-------------------------------------------------------------------------------------------

    # Removing DOCKER-USER CHAIN (it won't exist at first)
    firewall-cmd --permanent --direct --remove-chain ipv4 filter DOCKER-USER
    
    # Flush rules from DOCKER-USER chain (again, these won't exist at first; firewalld seems to remember these even if the chain is gone)
    firewall-cmd --permanent --direct --remove-rules ipv4 filter DOCKER-USER
    
    # Add the DOCKER-USER chain to firewalld
    firewall-cmd --permanent --direct --add-chain ipv4 filter DOCKER-USER

    # add loggs
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j LOG --log-prefix ' DOCKER: '
    
    # Add rules (see comments for details)
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT -m comment --comment "This allows docker containers to connect to the outside world"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s 172.18.0.0/16 -m comment --comment "allow internal docker communication"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s 172.17.0.0/16 -m comment --comment "allow internal docker communication"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s $KIRA_REGISTRY_SUBNET -m comment --comment "allow internal docker communication with registry"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s $KIRA_VALIDATOR_SUBNET -m comment --comment "allow internal docker communication with validator"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s $KIRA_SENTRY_SUBNET -m comment --comment "allow internal docker communication with entry"
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 0 -j RETURN -s $KIRA_SERVICE_SUBNET -m comment --comment "allow internal docker communication with frontend/interx"
    
    #  Block all other IPs. This rule has lowest precedence, so you can add allowed IP rules later.
    firewall-cmd --permanent --direct --add-rule ipv4 filter DOCKER-USER 10 -j REJECT -m comment --comment "reject all other traffic"

    #  unless there's an interface using the trusted zone that's directly recognized by firewalld (i.e. eth0) the trusted zone isn't marked as active
    #firewall-cmd --permanent --zone=trusted --add-interface=docker0
    #firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 3 -i docker0 -j ACCEPT
    #firewall-cmd --permanent --direct --add-rule ipv4 filter OUTPUT 3 -i docker0 -j ACCEPT
    
    echo "INFO: Default firewall zone: $(firewall-cmd --get-default-zone 2> /dev/null || echo "???")"
    
    IFace=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
    firewall-cmd --permanent --new-zone=demo || echo "INFO: Zone local-mode already exists"
    firewall-cmd --permanent --zone=demo --change-interface=$IFace
    #firewall-cmd --permanent --zone=demo --remove-port=$KIRA_FRONTEND_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_INTERX_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_P2P_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_RPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=$KIRA_SENTRY_GRPC_PORT/tcp
    firewall-cmd --permanent --zone=demo --add-port=22/tcp
    firewall-cmd --permanent --zone=demo --set-target=REJECT
    firewall-cmd --runtime-to-permanent
    
    firewall-cmd --reload
    firewall-cmd --get-zones
    firewall-cmd --zone=demo --list-all 
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
