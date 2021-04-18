
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/setup/docker.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

RESTART=$(service docker restart || echo "error")
ACTIVE=$(systemctl is-active docker || echo "inactive")
VERSION=$(docker -v || echo "error")
SETUP_CHECK="$KIRA_SETUP/docker-v0.0.11" 
if [ ! -f "$SETUP_CHECK" ] || [ "${VERSION,,}" == "error" ] || [ "${ACTIVE,,}" != "active" ] ; then
    echoInfo "INFO: Attempting to remove old docker..."
    
    docker system prune -f || echoWarn "WARNING: failed to prune docker system"
    service docker stop || echoWarn "WARNING: Failed to stop docker servce"
    apt remove --purge docker -y || echoWarn "WARNING: Failed to remove docker"
    apt remove --purge containerd -y || echoWarn "WARNING: Failed to remove containerd"
    apt remove --purge runc -y || echoWarn "WARNING: Failed to remove runc"
    apt remove --purge docker.io -y || echoWarn "WARNING: Failed to remove docker.io"
    apt autoremove -y docker.io || echoWarn "WARNING: Failed autoremove"
    iptables -F || echoWarn "WARNING: Failed to flush iptables"
    groupdel docker || echoWarn "WARNING: Failed to delete docker group"
    rm -rfv "/etc/docker" "/var/lib/docker" "/var/run/docker.sock"
    rm -rfv "/var/lib/containerd"

    echoInfo "INFO: Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-get update
    apt install -y bridge-utils containerd docker.io 

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
    service docker restart || echoWarn "WARNING: Failed to restart docker"
    sleep 5
    journalctl -u docker -n 100 --no-pager
    docker -v
    touch $SETUP_CHECK
else
    echoInfo "INFO: Docker $(docker -v) was already installed"
fi

echoInfo "INFO: Cleaning up dangling volumes..."
docker volume ls -qf dangling=true | xargs -r docker volume rm || echoWarn "WARNING: Failed to remove dangling vomues!"

