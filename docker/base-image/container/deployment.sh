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

# add-apt-repository "deb [arch=amd64] http://archive.ubuntu.com/ubuntu/ bionic universe"

echo "APT Update, Upfrade and Intall..."
apt-get update -y --fix-missing
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    file \
    build-essential \
    hashdeep \
    make \
    nodejs \
    node-gyp \
    tar \
    unzip \
    which \
    xz-utils \
    yarn \
    zip

GO_VERSION="1.14.2"
echo "INFO: Installing latest go version $GO_VERSION https://golang.org/doc/install ..."
wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz &>/dev/null
tar -C /usr/local -xvf go$GO_VERSION.linux-amd64.tar.gz &>/dev/null
