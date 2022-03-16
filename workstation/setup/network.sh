#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

SETUP_CHECK="$KIRA_SETUP/network-v0.0.12" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Setting up networking dependencies..."
    apt-get update -y
    echo "INFO: Installing DUC dependencies..."
    apt-get install -y autoconf libtool fuse nasm net-tools perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl

    echo "INFO: Cleaning up generic network dependencies..."
    apt-get remove -y ufw firewalld
    echo "INFO: Installing generic dependencies..."
    apt-get install -y ufw firewalld

    # resolve firewalld service restart conflicts
    systemctl disable ebtables || echo "INFO: Failed to disable ebtables"
    systemctl mask ebtables
    ln -s /sbin/iptables /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/iptables-restore /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/ip6tables /usr/sbin/ || echo "INFO: Failed symlink creation"
    ln -s /sbin/ip6tables-restore /usr/sbin/ || echo "INFO: Failed symlink creation"

    # ensure docker containers will have internet access & that firewall reload does not cause issues on ARM64
    FIREWALLD_CONF="/etc/firewalld/firewalld.conf"
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w fs.inotify.max_user_watches=524288
    CDHelper text lineswap --insert="net.ipv4.ip_forward=1" --prefix="net.ipv4.ip_forward=" --path=/etc/sysctl.conf --append-if-found-not=True
    CDHelper text lineswap --insert="IndividualCalls=yes" --prefix="IndividualCalls=" --path=$FIREWALLD_CONF --append-if-found-not=True
    CDHelper text lineswap --insert="FirewallBackend=iptables" --prefix="FirewallBackend=" --path=$FIREWALLD_CONF --append-if-found-not=True
    CDHelper text lineswap --insert="LogDenied=all" --prefix="LogDenied=" --path=$FIREWALLD_CONF --append-if-found-not=True
    # NOTE: To preview denied packets you can use command: dmesg | grep -i REJECT

    RESOLV_CFG="/etc/resolv.conf" && E=!
    CDHelper text lineswap --insert="nameserver $KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT" --regex="^nameserver ${KIRA_REGISTRY_DNS}:\d+" --path=$RESOLV_CFG --append-if-found-not=True
    CDHelper text lineswap --insert="nameserver $KIRA_REGISTRY_DNS" --regex="^nameserver ${KIRA_REGISTRY_DNS}(?$E:)" --path=$RESOLV_CFG --append-if-found-not=True

    systemctl enable firewalld || echo "INFO: Failed to disable firewalld"
    systemctl restart firewalld || echo "INFO: Failed to stop firewalld"
    
    touch $SETUP_CHECK
else
    echo "INFO: Networking dependencies were setup"
fi

