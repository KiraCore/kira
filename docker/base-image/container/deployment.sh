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
    file \
    build-essential \
    hashdeep \
    make \
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
apt install -y bc

ARCHITECTURE=$(uname -m)
GO_VERSION="1.15.6"
FLUTTER_VERSION="1.26.0-1.0.pre-dev"
DART_VERSION="2.12.0-205.0.dev"

if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
    GOLANG_ARCH="arm64"
    DART_ARCH="arm64"
else
    GOLANG_ARCH="amd64"
    DART_ARCH="x64"
fi

GO_TAR=go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz
FLUTTER_TAR="flutter_linux_$FLUTTER_VERSION.tar.xz"
DART_ZIP="dartsdk-linux-$DART_ARCH-release.zip"

echo "INFO: Installing latest go $GOLANG_ARCH version $GO_VERSION https://golang.org/doc/install ..."
cd /tmp

wget https://dl.google.com/go/$GO_TAR &>/dev/null
tar -C /usr/local -xvf $GO_TAR &>/dev/null

echo "Setting up essential flutter dependencies..."
wget https://storage.googleapis.com/flutter_infra/releases/dev/linux/$FLUTTER_TAR
mkdir -p /usr/lib # make sure flutter root directory exists
tar -C /usr/lib -xvf ./$FLUTTER_TAR

echo "Setting up essential dart dependencies..."
FLUTTER_CACHE=$FLUTTERROOT/bin/cache
rm -rfv $FLUTTER_CACHE/dart-sdk
mkdir -p $FLUTTER_CACHE # make sure flutter cache direcotry exists & essential files which prevent automatic update
touch $FLUTTER_CACHE/.dartignore
touch $FLUTTER_CACHE/engine-dart-sdk.stamp

wget https://storage.googleapis.com/dart-archive/channels/dev/release/$DART_VERSION/sdk/$DART_ZIP
unzip ./$DART_ZIP -d $FLUTTER_CACHE

flutter config --enable-web
flutter doctor
