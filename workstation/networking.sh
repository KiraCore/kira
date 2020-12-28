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

setup-after-rules() {
    IFace=$(route | grep '^default' | grep -o '[^ ]*$' | xargs)
    UWF_RULES="/etc/ufw/after.rules"
    TAG_START="#-DOCKER-BEHIND-UFW-V1-START"
    TAG_END="#-DOCKER-BEHIND-UFW-V1-END"
    sed -i "/$TAG_START/,/$TAG_END/d" $UWF_RULES
    
    if [ -z $(grep "$TAG_START" "$UWF_RULES") ] ; then
        echo "INFO: Tag '$TAG_START' is missing, overriding '$UWF_RULES' file"
        cat >> $UWF_RULES <<EOL
#-DOCKER-BEHIND-UFW-V1-START
*filter
:DOCKER-USER - [0:0]
:ufw-user-input - [0:0]

-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.17.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -j ufw-user-input

COMMIT
#-DOCKER-BEHIND-UFW-V1-END
EOL
    iptables -t nat -A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE # allow outbound connections to the internet from containers
    iptables -t nat -A POSTROUTING ! -o docker0 -s 172.18.0.0/16 -j MASQUERADE
    else
      echo "INFO: Tag '$TAG_START' was found within '$UWF_RULES' file no need to override"
    fi
}

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echo "INFO: Setting up demo mode networking..."
    ufw disable
    ufw --force reset
    setup-after-rules
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow 22/tcp
    ufw enable || ( ufw status verbose && ufw enable )
    ufw status verbose
    systemctl daemon-reload
    systemctl restart ufw
    ufw status verbose

    echo "INFO: Restarting docker..."
    systemctl restart docker || ( journalctl -u docker | tail -n 20 && systemctl restart docker )

    # WARNING, following command migt disable SSH access
    # CDHelper text lineswap --insert="ENABLED=yes" --prefix="ENABLED=" --path=/etc/ufw/ufw.conf --append-if-found-not=True
    
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
