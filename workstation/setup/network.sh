#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

SETUP_CHECK="$KIRA_SETUP/network-v0.0.8" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up networking dependencies..."
    apt-get update -y
    echo "INFO: Installing DUC dependencies..."
    apt-get install -y perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl
    echo "INFO: Installing XRDP dependencies..."
    apt-get install -y autoconf libtool fuse libpam0g-dev libjpeg-dev libfuse-dev libx11-dev libxfixes-dev \
        libxrandr-dev nasm gnome-tweak-tool net-tools
    echo "INFO: Installing generic dependencies..."
    apt-get install -y ufw firewalld

    # resolve firewalld service restart conflicts
    systemctl disable ebtables || echo "INFO: Failed to disable ebtables"
    systemctl mask ebtables
    ln -s /sbin/iptables /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/iptables-restore /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/ip6tables /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/ip6tables-restore /usr/sbin/ || echo "INFO: Failed symlink creation"

    systemctl enable firewalld || echo "INFO: Failed to disable firewalld"
    systemctl restart firewalld || echo "INFO: Failed to stop firewalld"


    touch $SETUP_CHECK
else
    echo "INFO: Networking dependencies were setup"
fi

