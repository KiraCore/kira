#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

SETUP_CHECK="$KIRA_SETUP/network-v0.0.4" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up networking dependencies..."
    apt-get update -y
    echo "INFO: Installing DUC dependencies..."
    apt-get install -y perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl
    echo "INFO: Installing XRDP dependencies..."
    apt-get install -y autoconf libtool fuse libpam0g-dev libjpeg-dev libfuse-dev libx11-dev libxfixes-dev \
        libxrandr-dev nasm gnome-tweak-tool net-tools
    echo "INFO: Installing generic dependencies..."
    apt-get install -y ufw

    DEFAULT_UFW="/etc/default/ufw"
    #CDHelper text lineswap --insert="IPV6=no" --prefix="IPV6=" --path="$DEFAULT_UFW" --append-if-found-not=True
    #CDHelper text lineswap --insert="DEFAULT_FORWARD_POLICY=\"ACCEPT\"" --prefix="DEFAULT_FORWARD_POLICY=" --path="$DEFAULT_UFW" --append-if-found-not=True
    #CDHelper text lineswap --insert="MANAGE_BUILTINS=yes" --prefix="MANAGE_BUILTINS=" --path="$DEFAULT_UFW" --append-if-found-not=True
    ##CDHelper text lineswap --insert="DOCKER_OPTS=\"--iptables=false\"" --prefix="DOCKER_OPTS=" --path="$DEFAULT_UFW" --append-if-found-not=True

    touch $SETUP_CHECK
else
    echo "INFO: Networking dependencies were setup"
fi

