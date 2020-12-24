
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

GO_VERSION="1.15.6"
GOROOT="/usr/local/go"
GOPATH="/home/go"
GOBIN="${GOROOT}/bin"
SETUP_CHECK="$KIRA_SETUP/go-v${GO_VERSION}-0"

if [ ! -f "$SETUP_CHECK" ] ; then
    echo "INFO: Ensuring golang is removed ..."
    apt-get remove golang-go -y
    apt-get remove --auto-remove golang-go -y
    echo "INFO: Setting up environment variables ..."
    CDHelper text lineswap --insert="GO_VERSION=$GO_VERSION" --prefix="GO_VERSION=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOROOT=$GOROOT" --prefix="GOROOT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOPATH=$GOPATH" --prefix="GOPATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOBIN=$GOBIN" --prefix="GOBIN=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GO111MODULE=on" --prefix="GO111MODULE=" --path=$ETC_PROFILE --append-if-found-not=True
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOPATH" --prefix="PATH=" --and-contains-not=":$GOPATH" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOROOT" --prefix="PATH=" --and-contains-not=":$GOROOT" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOBIN" --prefix="PATH=" --and-contains-not=":$GOBIN" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    echo "INFO: Installing latest go version $GO_VERSION https://golang.org/doc/install ..."
    wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
    tar -C /usr/local -xvf go$GO_VERSION.linux-amd64.tar.gz
    go version
    go env
    touch $SETUP_CHECK
else
    echo "INFO: Go $(go version) was already installed"
fi
