
#!/bin/bash
set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

exec &> >(tee -a "$KIRA_DUMP/setup.log")


KIRA_SETUP_SYSCTL="$KIRA_SETUP/systemctl-v0.0.1" 
if [ ! -f "$KIRA_SETUP_SYSCTL" ] ; then
    echo "Installing custom systemctl..."
    wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl2
    chmod -v 777 /usr/local/bin/systemctl2
    
    systemctl2 --version
    touch $KIRA_SETUP_SYSCTL
else
    echo "systemctl2 was already installed."
fi
