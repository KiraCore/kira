
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

GO_VERSION="1.15.11"
GOROOT="/usr/local/go"
GOPATH="/home/go"
GOCACHE="/home/go/cache"
GOBIN="${GOROOT}/bin"
ARCHITECTURE=$(uname -m)

ESSENTIALS_HASH=$(echo "$KIRA_HOME-$ARCHITECTURE-$GO_VERSION-1" | md5)
SETUP_CHECK="$KIRA_SETUP/go-setup-1-$ESSENTIALS_HASH"
if [ ! -f "$SETUP_CHECK" ] ; then
    echoInfo "INFO: Ensuring golang is removed ..."
    apt-get remove golang-go -y
    apt-get remove --auto-remove golang-go -y
    echoInfo "INFO: Setting up environment variables ..."
    mkdir -p $GOCACHE
    CDHelper text lineswap --insert="GO_VERSION=$GO_VERSION" --prefix="GO_VERSION=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOROOT=$GOROOT" --prefix="GOROOT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOPATH=$GOPATH" --prefix="GOPATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOBIN=$GOBIN" --prefix="GOBIN=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GO111MODULE=on" --prefix="GO111MODULE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="GOCACHE=$GOCACHE" --prefix="GOCACHE=" --path=$ETC_PROFILE --append-if-found-not=True
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOPATH" --prefix="PATH=" --and-contains-not=":$GOPATH" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOROOT" --prefix="PATH=" --and-contains-not=":$GOROOT" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$GOBIN" --prefix="PATH=" --and-contains-not=":$GOBIN" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e

    if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
        GOLANG_ARCH="arm64"
    else
        GOLANG_ARCH="amd64"
    fi

    echoInfo "INFO: Installing latest go version $GO_VERSION https://golang.org/doc/install ..."
    wget https://dl.google.com/go/go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz
    tar -C /usr/local -xvf go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz
    go version
    go env
    touch $SETUP_CHECK
else
    echoInfo "INFO: Go $(go version) was already installed"
fi
