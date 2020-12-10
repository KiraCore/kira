
#!/bin/bash
set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

exec &> >(tee -a "$KIRA_DUMP/setup.log")

VERSION=$(docker -v || echo "Error")
SETUP_CHECK="$KIRA_SETUP/docker-v0.0.2" 
if [ ! -f "$SETUP_CHECK" ] || [ "$VERSION" == "Error" ] ; then
    echo "INFO: Installing Docker..."
    apt-get update
    apt install docker.io -y
    systemctl enable --now docker
    docker -v
    touch $SETUP_CHECK
else
    echo "INFO: Docker $(docker -v) was already installed"
fi
