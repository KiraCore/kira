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

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i $IFace -j ufw-user-input
-A DOCKER-USER -i $IFace -j DROP
COMMIT
#-DOCKER-BEHIND-UFW-V1-END
EOL
else
  echo "INFO: Tag '$TAG_START' was found within '$UWF_RULES' file no need to override"
fi

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echo "INFO: Setting up demo mode networking..."
    ufw disable
    ufw --force reset
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow 22/tcp
    ufw enable || ( ufw status verbose && ufw enable )
    ufw status verbose
    systemctl daemon-reload
    systemctl restart ufw
    ufw status verbose

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
