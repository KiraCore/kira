
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

RESTART=$(service docker restart || echo "error")
ACTIVE=$(systemctl is-active docker || echo "inactive")
VERSION=$(docker -v || echo "error")
SETUP_CHECK="$KIRA_SETUP/docker-v0.0.9" 
if [ ! -f "$SETUP_CHECK" ] || [ "${VERSION,,}" == "error" ] || [ "${ACTIVE,,}" != "active" ] ; then
    echo "INFO: Attempting to remove old docker..."
    service docker stop || echo "WARNING: Failed to stop docker servce"
    apt remove --purge docker -y || echo "WARNING: Failed to remove docker"
    apt remove --purge containerd -y || echo "WARNING: Failed to remove containerd"
    apt remove --purge runc -y || echo "WARNING: Failed to remove runc"
    apt remove --purge docker-engine -y || echo "WARNING: Failed to remove docker-engine"
    apt remove --purge docker.io -y || echo "WARNING: Failed to remove docker.io"
    apt remove --purge docker.io -y || echo "WARNING: Failed to remove docker.io"
    apt remove --purge docker-ce -y || echo "WARNING: Failed to remove docker-ce"
    apt remove --purge docker-ce-cli -y || echo "WARNING: Failed to remove docker-ce-cli"
    apt remove --purge containerd.io -y || echo "WARNING: Failed to remove containerd.io"
    apt autoremove -y || echo "WARNING: Failed autoremove"
    rm -rfv /etc/docker
    rm -rfv /var/lib/docker

    echo "INFO: Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    apt-get update
    #apt install docker-ce docker-ce-cli containerd.io -y
    apt install containerd docker.io -y

    DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
    rm -f -v $DOCKER_DAEMON_JSON
    cat >$DOCKER_DAEMON_JSON <<EOL
{
  "iptables": false
}
EOL

    systemctl enable --now docker
    docker -v
    touch $SETUP_CHECK
else
    echo "INFO: Docker $(docker -v) was already installed"
fi

echo "INFO: Cleaning up dangling volumes..."
docker volume ls -qf dangling=true | xargs -r docker volume rm || echo "INFO: Failed to remove dangling vomues!"

#mknod -m 777 /dev/null c 1 3
#mknod -m 777 /dev/zero c 1 5
