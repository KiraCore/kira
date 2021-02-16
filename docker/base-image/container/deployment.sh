#!/bin/bash

exec 2>&1
set -e
set -x

apt-get update -y
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common curl wget git nginx apt-transport-https

echo "APT Update, Update and Intall..."
apt-get update -y --fix-missing
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    file build-essential net-tools hashdeep make \
    nodejs \
    node-gyp \
    tar \
    unzip \
    xz-utils \
    yarn \
    zip \
    protobuf-compiler \
    golang-goprotobuf-dev \
    golang-grpc-gateway \
    golang-github-grpc-ecosystem-grpc-gateway-dev \
    clang \
    cmake \
    gcc \
    g++ \
    pkg-config \
    libudev-dev \
    libusb-1.0-0-dev \
    curl \
    iputils-ping \
    nano \
    jq 

apt update -y
apt install -y bc dnsutils psmisc 

ARCHITECTURE=$(uname -m)
GO_VERSION="1.15.6"
CDHELPER_VERSION="v0.6.50"
FLUTTER_CHANNEL="beta"
FLUTTER_VERSION="1.25.0-8.3.pre-$FLUTTER_CHANNEL"
DART_CHANNEL_PATH="be/raw"
DART_VERSION="latest"


if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
    GOLANG_ARCH="arm64"
    DART_ARCH="arm64"
    CDHELPER_ARCH="arm64"
    CDHELPER_EXPECTED_HASH="6cfd73a429463aa9f2e5f9e8462f5ada50ecaa1b4e21ad6d05caef4f21943273"
else
    GOLANG_ARCH="amd64"
    DART_ARCH="x64"
    CDHELPER_ARCH="x64"
    CDHELPER_EXPECTED_HASH="6345e3c37cb5eddee659d1a6c7068ff6cf0a1e6a74d1f6f5fec747338f9ebdaf"
fi

GO_TAR=go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz
FLUTTER_TAR="flutter_linux_$FLUTTER_VERSION.tar.xz"
DART_ZIP="dartsdk-linux-$DART_ARCH-release.zip"

echo "INFO: Installing CDHelper tool"

if [ "$FILE_HASH" != "$CDHELPER_EXPECTED_HASH" ]; then
    rm -f -v ./CDHelper-linux-$CDHELPER_ARCH.zip
    wget "https://github.com/asmodat/CDHelper/releases/download/$CDHELPER_VERSION/CDHelper-linux-$CDHELPER_ARCH.zip"
    FILE_HASH=$(sha256sum ./CDHelper-linux-$CDHELPER_ARCH.zip | awk '{ print $1 }')
 
    if [ "$FILE_HASH" != "$CDHELPER_EXPECTED_HASH" ]; then
        echo -e "\nDANGER: Failed to check integrity hash of the CDHelper tool !!!\nERROR: Expected hash: $CDHELPER_EXPECTED_HASH, but got $FILE_HASH\n"
        exit 1
    fi
else
    echo "INFO: CDHelper tool was already downloaded"
fi
 
INSTALL_DIR="/usr/local/bin/CDHelper"
rm -rfv $INSTALL_DIR
mkdir -pv $INSTALL_DIR
unzip CDHelper-linux-$CDHELPER_ARCH.zip -d $INSTALL_DIR
chmod -R -v 555 $INSTALL_DIR
 
ls -l /bin/CDHelper || echo "INFO: Symlink not found"
rm /bin/CDHelper || echo "INFO: Failed to remove old symlink"
ln -s $INSTALL_DIR/CDHelper /bin/CDHelper || echo "INFO: CDHelper symlink already exists"
 
CDHelper version

CDHelper text lineswap --insert="source $ETC_PROFILE" --prefix="source $ETC_PROFILE" --path=$BASHRC --append-if-found-not=True

echo "INFO: Installing latest go $GOLANG_ARCH version $GO_VERSION https://golang.org/doc/install ..."
cd /tmp

wget https://dl.google.com/go/$GO_TAR &>/dev/null
tar -C /usr/local -xvf $GO_TAR &>/dev/null

echo "Setting up essential flutter dependencies..."
wget https://storage.googleapis.com/flutter_infra/releases/$FLUTTER_CHANNEL/linux/$FLUTTER_TAR
mkdir -p /usr/lib # make sure flutter root directory exists
tar -C /usr/lib -xvf ./$FLUTTER_TAR

echo "Setting up essential dart dependencies..."
FLUTTER_CACHE=$FLUTTERROOT/bin/cache
rm -rfv $FLUTTER_CACHE/dart-sdk
mkdir -p $FLUTTER_CACHE # make sure flutter cache direcotry exists & essential files which prevent automatic update
touch $FLUTTER_CACHE/.dartignore
touch $FLUTTER_CACHE/engine-dart-sdk.stamp

wget https://storage.googleapis.com/dart-archive/channels/$DART_CHANNEL_PATH/$DART_VERSION/sdk/$DART_ZIP
unzip ./$DART_ZIP -d $FLUTTER_CACHE

flutter config --enable-web
flutter doctor
