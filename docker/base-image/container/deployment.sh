#!/bin/bash

exec 2>&1
set -e
set -x

# Local Update
# (rm -fv $KIRA_INFRA/docker/base-image/container/deployment.sh) && nano $KIRA_INFRA/docker/base-image/container/deployment.sh

apt-get update -y
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common curl wget git

# apt-get update -y --fix-missing
# curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
# curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

add-apt-repository "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic universe"

echo "APT Update, Upfrade and Intall..."
apt-get update -y --fix-missing
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    build-essential \
    hashdeep \
    make \
    nodejs \
    node-gyp \
    tar \
    unzip \
    yarn \
    zip

ETC_PROFILE="/etc/profile"
curl -O https://storage.googleapis.com/golang/go1.15.3.linux-amd64.tar.gz >/dev/null
tar -xvf go1.15.3.linux-amd64.tar.gz >/dev/null
echo "export GOPATH=$HOME/go" >>$ETC_PROFILE
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >>$ETC_PROFILE
source $ETC_PROFILE
go version
