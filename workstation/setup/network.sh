#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

#SETUP_CHECK="$KIRA_SETUP/network-v0.0.12" 
#if [ ! -f "$SETUP_CHECK" ] ; then
    echoInfo "INFO: Setting up networking dependencies..."
    apt-get update -y
    #echo "INFO: Cleaning up generic network dependencies..."
    #apt-get remove -y ufw firewalld
    echoInfo "INFO: Installing generic dependencies..."
    apt-get install -y ufw firewalld

    # resolve firewalld service restart conflicts
    systemctl stop ebtables || echoWarn "WARNING: Failed to disable ebtables"
    systemctl mask ebtables || echoWarn "WARNING: Failed to mask ebtables"
    ln -s /sbin/iptables /usr/sbin/ || echoWarn "WARNING: Failed symlink creation"
    ln -s /sbin/iptables-restore /usr/sbin/ || echoWarn "WARNING: Failed symlink creation"
    ln -s /sbin/ip6tables /usr/sbin/ || echoWarn "WARNING: Failed symlink creation"
    ln -s /sbin/ip6tables-restore /usr/sbin/ || echoWarn "WARNING: Failed symlink creation"

    # ensure docker containers will have internet access & that firewall reload does not cause issues on ARM64
    FIREWALLD_CONF="/etc/firewalld/firewalld.conf"
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w fs.inotify.max_user_watches=524288
    setVar "net.ipv4.ip_forward" "1" /etc/sysctl.conf
    setVar "IndividualCalls" "yes" $FIREWALLD_CONF
    setVar "FirewallBackend" "iptables" $FIREWALLD_CONF
    setVar "LogDenied" "all" $FIREWALLD_CONF
    # NOTE: To preview denied packets you can use command: dmesg | grep -i REJECT

    systemctl enable firewalld || echoWarn "WARNING: Failed to disable firewalld"
    systemctl restart firewalld || echoWarn "WARNING: Failed to restart firewalld"
    
#    touch $SETUP_CHECK
#else
#    echo "INFO: Networking dependencies were setup"
#fi

