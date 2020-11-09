#!/bin/bash

exec 2>&1
set -e
set -x

VERSION=$1
SCHEDULER=$2
INSTALL_DIR=$3
SERVICE_FILE=$4

CDHelperVersion=$(CDHelper version --silent=true || echo "v0.0.0")
VEREQ=$(CDHelper text vereq --old="$CDHelperVersion" --new="$VERSION" --silent=true || echo "-1")

[ -z "$SCHEDULER" ] && SCHEDULER="False"
[ -z "$INSTALL_DIR" ] && INSTALL_DIR="/usr/local/bin"
[ -z "$SERVICE_FILE" ] && SERVICE_FILE="/etc/systemd/system/scheduler.service"

INSTALL_DIR=$INSTALL_DIR/CDHelper
INSTALL_PATH=$INSTALL_DIR/CDHelper
echo "------------------------------------------------"
echo "|       STARTED: CDHELPER UPDATE v0.0.1        |"
echo "|----------------------------------------------|"
echo "|    OLD VERSION: $CDHelperVersion"
echo "|    NEW VERSION: $VERSION"
echo "| VERSIONS EQUAL: $VEREQ"
echo "|      SCHEDULER: $SCHEDULER"
echo "|   SERVICE FILE: $SERVICE_FILE"
echo "|    INSTALL DIR: $INSTALL_DIR"
echo "|_______________________________________________"

if [ "$VEREQ" == "1" ] || [ "$VEREQ" == "0" ] ; then
    echo "CDHelper will not be updated, old version is older or equal to new."
    exit 0
else
    echo "New version detected, installing..."
fi

cd /tmp
rm -f -v ./CDHelper-linux-x64.zip
wget https://github.com/asmodat/CDHelper/releases/download/$VERSION/CDHelper-linux-x64.zip
rm -rfv $INSTALL_DIR
unzip CDHelper-linux-x64.zip -d $INSTALL_DIR
chmod -R -v 777 $INSTALL_DIR

ln -s $INSTALL_PATH /bin/CDHelper || echo "CDHelper symlink already exists"

CDHelper version

if [ "$SCHEDULER" == "True" ] ; then
    rm -f -v $SERVICE_FILE
    cat > $SERVICE_FILE << EOL
[Unit]
Description=Asmodat Deployment Scheduler
After=network.target
[Service]
Type=simple
User=root
EnvironmentFile=/etc/environment
ExecStart=$INSTALL_PATH scheduler github
WorkingDirectory=/root
Restart=on-failure
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOL
    systemctl2 enable scheduler.service || echo "Failed to enable systemd service" && exit 1
fi

echo "------------------------------------------------"
echo "|     FINISHED: CDHELPER UPDATE v0.0.1         |"
echo "------------------------------------------------"


