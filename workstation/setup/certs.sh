
#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &> /dev/null

SETUP_CHECK="$KIRA_SETUP/certs-v0.0.6" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Installing certificates and package references..."
    apt-get update -y --fix-missing
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
    add-apt-repository "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic universe"
    add-apt-repository "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main"
    add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
    add-apt-repository "deb [arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main"
    apt-add-repository ppa:maarten-fonville/android-studio -y
    touch $SETUP_CHECK
else
    echo "INFO: Certs and refs were already installed."
fi
