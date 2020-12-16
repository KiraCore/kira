
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec &> >(tee -a "$KIRA_DUMP/setup.log")

SETUP_CHECK="$KIRA_SETUP/go-v${GO_VERSION}-0" 
if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Ensuring golang is removed ..."
    apt-get remove golang-go -y
    apt-get remove --auto-remove golang-go -y
    echo "INFO: Installing latest go version $GO_VERSION https://golang.org/doc/install ..."
    wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
    tar -C /usr/local -xvf go$GO_VERSION.linux-amd64.tar.gz
    go version
    go env
    touch $SETUP_CHECK
else
    echo "INFO: Go $(go version) was already installed"
fi
