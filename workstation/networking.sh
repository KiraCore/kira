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
    UWF_AFTER="/etc/ufw/after.rules"
    UWF_BEFORE="/etc/ufw/before.init"

    cat >> $UWF_AFTER <<EOL
#-DOCKER-BEHIND-UFW-V1-START
*filter
:DOCKER-USER - [0:0]
:ufw-user-input - [0:0]
:ufw-after-logging-forward - [0:0]

-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -i $IFace -j ufw-user-input
-A DOCKER-USER -i $IFace -j ufw-after-logging-forward
-A DOCKER-USER -i $IFace -j DROP

COMMIT
#-DOCKER-BEHIND-UFW-V1-END
EOL

    cat > $UWF_BEFORE <<EOL
#!/bin/sh
set -e

case "\$1" in
start)
    # typically required
    ;;
stop)
    iptables -F DOCKER-USER || true
    iptables -A DOCKER-USER -j RETURN || true
    iptables -X ufw-user-input || true
    # typically required
    ;;
status)
    # optional
    ;;
flush-all)
    # optional
    ;;
*)
    echo "'\$1' not supported"
    echo "Usage: before.init {start|stop|flush-all|status}"
    ;;
esac
EOL

chmod +x $UWF_AFTER
chmod +x $UWF_BEFORE

    # iptables -t nat -A POSTROUTING ! -o docker0 -s 172.17.0.0/16 -j MASQUERADE # allow outbound connections to the internet from containers
    # iptables -t nat -A POSTROUTING ! -o docker0 -s 172.18.0.0/16 -j MASQUERADE
}

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echo "INFO: Setting up demo mode networking..."
    ufw disable
    ufw --force reset
    ufw logging on # required to setup logging rules
    setup-after-rules
    ufw default allow outgoing
    ufw default allow incoming
    # ufw default deny incoming
    # ufw allow 22/tcp
    ufw status verbose
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
