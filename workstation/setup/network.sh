#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

SETUP_CHECK="$KIRA_SETUP/network-v0.0.1" 
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

    CDHelper text lineswap --insert="DEFAULT_FORWARD_POLICY=\"DROP\"" --prefix="DEFAULT_FORWARD_POLICY=" --path="/etc/default/ufw" --append-if-found-not=True
    touch $SETUP_CHECK
else
    echo "INFO: Networking dependencies were setup"
fi

