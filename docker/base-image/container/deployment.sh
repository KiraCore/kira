#!/bin/bash

exec 2>&1
set -e
set -x

source /etc/profile

apt-get update -y
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common curl wget git nginx

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

ARCHITECTURE=$(uname -m)
GO_VERSION="1.15.6"

if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
    GOLANG_ARCH="arm64"
    DART_ARCH="arm64"
else
    GOLANG_ARCH="amd64"
    DART_ARCH="x64"
fi

echo "INFO: Installing latest go $GOLANG_ARCH version $GO_VERSION https://golang.org/doc/install ..."

wget https://dl.google.com/go/go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz &>/dev/null
tar -C /usr/local -xvf go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz &>/dev/null

echo "Setting up essential flutter dependencies..."
FLUTTER_VERSION="1.25.0-8.2.pre-beta"
FLUTTER_TAR="flutter_linux_$FLUTTER_VERSION.tar.xz"

wget https://storage.googleapis.com/flutter_infra/releases/beta/linux/$FLUTTER_TAR
mkdir -p $FLUTTERROOT # make sure flutter root directory exists
tar -C $FLUTTERROOT -xvf ./$FLUTTER_TAR

echo "Setting up essential dart dependencies..."
DART_VERSION="2.12.0-133.2.beta"
DART_ZIP="dartsdk-linux-$DART_ARCH-release.zip"

FLUTTER_CACHE=$FLUTTERROOT/bin/cache
rm -rfv $FLUTTER_CACHE/dart-sdk

wget https://storage.googleapis.com/dart-archive/channels/beta/release/$DART_VERSION/sdk/$DART_ZIP
mkdir -p $FLUTTER_CACHE # make sure flutter cache direcotry exists
unzip ./$DART_ZIP -d $FLUTTER_CACHE

flutter config --enable-web
flutter doctor
