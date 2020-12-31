
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

RESTART=$(service docker restart || echo "error")
ACTIVE=$(systemctl is-active docker || echo "inactive")
VERSION=$(docker -v || echo "error")
SETUP_CHECK="$KIRA_SETUP/docker-v0.0.2" 
if [ ! -f "$SETUP_CHECK" ] || [ "${VERSION,,}" == "error" ] || [ "${ACTIVE,,}" != "active" ] ; then
    echo "INFO: Attempting to remove old docker..."
    service docker stop || echo "WARNING: Failed to stop docker servce"
    apt remove --purge docker.io -y || echo "WARNING: Failed to remove docker"
    apt remove -y docker-ce docker-ce-cli containerd.io || echo "WARNING: Failed to remove docker-ce"
    rm -rfv /etc/docker
    rm -rfv /var/lib/docker
    echo "INFO: Installing Docker..."
    apt-get update
    apt install docker.io -y
    systemctl enable --now docker
    docker -v
    touch $SETUP_CHECK
else
    echo "INFO: Docker $(docker -v) was already installed"
fi
