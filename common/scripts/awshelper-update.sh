#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv /kira/repos/infra/common/scripts/awshelper-update.sh) && nano /kira/repos/infra/common/scripts/awshelper-update.sh && chmod 777 /kira/repos/infra/common/scripts/awshelper-update.sh
VERSION=$1
INSTALL_DIR=$2

AWSHelperVersion=$(AWSHelper version --silent=true || echo "v0.0.0")
VEREQ=$(CDHelper text vereq --old="$AWSHelperVersion" --new="$VERSION" --silent=true || echo "-1")

[ -z "$INSTALL_DIR" ] && INSTALL_DIR="/usr/local/bin"

INSTALL_DIR=$INSTALL_DIR/AWSHelper
echo "------------------------------------------------"
echo "|       STARTED: AWSHELPER UPDATE v0.0.1       |" 
echo "|-----------------------------------------------"
echo "|    OLD-VERSION: $AWSHelperVersion"
echo "|    NEW-VERSION: $VERSION"
echo "| VERSIONS EQUAL: $VEREQ"
echo "|    INSTALL DIR: $INSTALL_DIR"
echo "|_______________________________________________"

if [ "$VEREQ" == "1" ] || [ "$VEREQ" == "0" ] ; then
    echo "AWSHelper will not be updated, old version is older or equal to new."
    exit 0
else
    echo "New version detected, installing..."
fi

cd /tmp
rm -f -v ./AWSHelper-linux-x64.zip
wget https://github.com/asmodat/AWSHelper/releases/download/$VERSION/AWSHelper-linux-x64.zip
rm -rfv $INSTALL_DIR
unzip AWSHelper-linux-x64.zip -d $INSTALL_DIR
chmod -Rv 777 $INSTALL_DIR

ls -l /bin/AWSHelper || echo "AWSHelper symlink not found"
rm /bin/AWSHelper || echo "Removing old AWSHelper symlink"
ln -s $INSTALL_DIR/AWSHelper /bin/AWSHelper || echo "AWSHelper symlink already exists"

AWSHelper version

echo "------------------------------------------------"
echo " FINISHED: AWSHELPER UPDATE v0.0.1"
echo "------------------------------------------------"
