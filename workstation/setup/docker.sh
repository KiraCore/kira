
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/setup/docker.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

RESTART=$(service docker restart || echo "error")
ACTIVE=$(systemctl is-active docker || echo "inactive")
VERSION=$(docker -v || echo "error")

ESSENTIALS_HASH=$(echo "$KIRA_HOME-" | md5sum | awk '{ print $1 }' || echo -n "")
SETUP_CHECK="$KIRA_SETUP/docker-1-$ESSENTIALS_HASH"
SETUP_CHECK_REBOOT="$SETUP_CHECK-reboot"
if [ ! -f "$SETUP_CHECK" ] || [ "${VERSION,,}" == "error" ] || [ "${ACTIVE,,}" != "active" ] ; then
    echoInfo "INFO: Attempting to remove old docker..."
    docker system prune -f || echoWarn "WARNING: failed to prune docker system"
    $KIRA_SCRIPTS/docker-stop.sh || echoWarn "WARNING: Failed to stop docker servce"

    echoInfo "INFO: Removing hanging docker-network interfaces..."
    ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)
    for f in $ifaces_iterate ; do
        if [ "$f" == "docker0" ] || [[ "$f" =~ ^br-.*$ ]]; then
            echoInfo "INFO: Found docker network interface $f, removing..."
            ip link set $f down || echoWarn "WARNINIG: Failed ip link set down interface $f"
            brctl delbr $f || echoWarn "WARNINIG: Failed brctl delbr interface $f"
        else
            echoInfo "INFO: Network interface $f does not belong to docker"
        fi
    done

    dpkg --configure -a || echoWarn "WARNING: Failed dpkg configuration"
    apt remove --purge docker -y || echoWarn "WARNING: Failed to remove docker"
    apt remove --purge containerd -y || echoWarn "WARNING: Failed to remove containerd"
    apt remove --purge docker.io -y || echoWarn "WARNING: Failed to remove docker.io"
    apt remove --purge bridge-utils -y || echoWarn "WARNING: Failed to remove bridge-utils"

    dpkg --configure -a || echoWarn "WARNING: Failed dpkg configuration"
    apt autoremove -y docker.io || echoWarn "WARNING: Failed docker.io autoremove"
    apt autoremove -y bridge-utils || echoWarn "WARNING: Failed bridge-utils autoremove"
    apt autoremove -y containerd || echoWarn "WARNING: Failed containerd autoremove"

    groupdel docker || echoWarn "WARNING: Failed to delete docker group"
    rm -rfv "/etc/docker" "/var/lib/docker" "/var/run/docker.sock"
    rm -rfv "/var/lib/containerd"

    if ! timeout 2 ping -c1 "download.docker.com" &>/dev/null ; then
        firewall-cmd --permanent --delete-zone=docker || echoWarn "WARNING: Failed to delete docker zone"
        firewall-cmd --set-default-zone=public || echoWarn "INFO: WARNING to set default zone"
        firewall-cmd --reload
        firewall-cmd --complete-reload
        systemctl restart firewalld

        echoErr "ERROR: System must be rebooted, no connection with 'download.docker.com'"
        if [ ! -f $SETUP_CHECK_REBOOT ] ; then
            touch $SETUP_CHECK_REBOOT
            reboot
        else
            sleep 10
            exit 1
        fi
    fi

    echoInfo "INFO: Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-get update

    dpkg --configure -a || echoWarn "WARNING: Failed dpkg configuration"
    apt install -y bridge-utils containerd docker.io 

    DOCKER_SERVICE="/lib/systemd/system/docker.service"
    sed -i "s/fd:/unix:/" $DOCKER_SERVICE  || echoWarn "WARNING: Failed to substitute fd with unix in $DOCKER_SERVICE"

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "iptables": false,
  "storage-driver": "overlay2"
}
EOL

    systemctl enable --now docker
    sleep 5
    service docker restart || echoWarn "WARNING: Failed to restart docker ($USER)"
    sleep 5
    journalctl -u docker -n 100 --no-pager
    docker -v

    $KIRA_MANAGER/setup/registry.sh

    touch $SETUP_CHECK
else
    echoInfo "INFO: Docker $(docker -v) was already installed"
fi

echoInfo "INFO: Cleaning up dangling volumes..."
docker volume ls -qf dangling=true | xargs -r docker volume rm || echoWarn "WARNING: Failed to remove dangling vomues!"

