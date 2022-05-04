#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -e
set -x

apt-get update -y
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common curl wget git apt-transport-https

echoInfo "INFO: APT Update, Update and Intall..."
apt-get update -y --fix-missing
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    file build-essential net-tools hashdeep make nodejs node-gyp tar unzip xz-utils yarn zip p7zip-full \
    protobuf-compiler golang-goprotobuf-dev golang-grpc-gateway golang-github-grpc-ecosystem-grpc-gateway-dev \
    clang cmake gcc g++ pkg-config libudev-dev libusb-1.0-0-dev curl iputils-ping nano jq python python3 python3-pip \
    bash libglu1-mesa lsof

apt update -y
apt install -y bc dnsutils psmisc netcat default-jre default-jdk

pip3 install ECPy

ARCHITECTURE=$(uname -m)
GO_VERSION="1.17.2"
CDHELPER_VERSION="v0.6.51"
FLUTTER_CHANNEL="stable"
FLUTTER_VERSION="2.5.2-${FLUTTER_CHANNEL}"
DART_CHANNEL_PATH="stable/release"
DART_VERSION="2.14.3"
GLOB_STORE_DIR="/var/kiraglob"

mkdir -p $GLOB_STORE_DIR

if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
    GOLANG_ARCH="arm64"
    DART_ARCH="arm64"
    CDHELPER_ARCH="arm64"
    CDHELPER_EXPECTED_HASH="c2e40c7143f4097c59676f037ac6eaec68761d965bd958889299ab32f1bed6b3"
else
    GOLANG_ARCH="amd64"
    DART_ARCH="x64"
    CDHELPER_ARCH="x64"
    CDHELPER_EXPECTED_HASH="082e05210f93036e0008658b6c6bd37ab055bac919865015124a0d72e18a45b7"
fi

GO_TAR=go$GO_VERSION.linux-$GOLANG_ARCH.tar.gz
FLUTTER_TAR="flutter_linux_$FLUTTER_VERSION.tar.xz"
DART_ZIP="dartsdk-linux-$DART_ARCH-release.zip"

echoInfo "INFO: Installing CDHelper tool"

if [ "$FILE_HASH" != "$CDHELPER_EXPECTED_HASH" ]; then
    rm -f -v ./CDHelper-linux-$CDHELPER_ARCH.zip
    wget "https://github.com/asmodat/CDHelper/releases/download/$CDHELPER_VERSION/CDHelper-linux-$CDHELPER_ARCH.zip"
    FILE_HASH=$(sha256 ./CDHelper-linux-$CDHELPER_ARCH.zip)
 
    if [ "$FILE_HASH" != "$CDHELPER_EXPECTED_HASH" ]; then
        echoErr "ERROR: Failed to check integrity hash of the CDHelper tool!"
        echoErr "ERROR: Expected hash: $CDHELPER_EXPECTED_HASH, but got $FILE_HASH"
        exit 1
    fi
else
    echoInfo "INFO: CDHelper tool was already downloaded"
fi
