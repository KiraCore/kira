#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -e
set -x

apt-get update -y
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common curl wget git nginx apt-transport-https

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
 
INSTALL_DIR="/usr/local/bin/CDHelper"
rm -rfv $INSTALL_DIR
mkdir -pv $INSTALL_DIR
unzip CDHelper-linux-$CDHELPER_ARCH.zip -d $INSTALL_DIR
chmod -R -v 555 $INSTALL_DIR
 
ls -l /bin/CDHelper || echoWarn "INFO: Symlink not found"
rm /bin/CDHelper || echoWarn "INFO: Failed to remove old symlink"
ln -s $INSTALL_DIR/CDHelper /bin/CDHelper || echoWarn "INFO: CDHelper symlink already exists"
 
CDHelper version

CDHelper text lineswap --insert="source $ETC_PROFILE" --prefix="source $ETC_PROFILE" --path=$BASHRC --append-if-found-not=True

echoInfo "INFO: Installing latest go $GOLANG_ARCH version $GO_VERSION https://golang.org/doc/install ..."
cd /tmp

wget https://dl.google.com/go/$GO_TAR &>/dev/null
tar -C /usr/local -xvf $GO_TAR &>/dev/null
go version

rm -fv CDHelper-linux-$CDHELPER_ARCH.zip

echoInfo "INFO: Installing essential KIRA tools"

cd $SELF_HOME
TOOLS_DIR="$SELF_HOME/tools"
KMS_KEYIMPORT_DIR="$TOOLS_DIR/tmkms-key-import"
PRIV_KEYGEN_DIR="$TOOLS_DIR/priv-validator-key-gen"
TMCONNECT_DIR="$TOOLS_DIR/tmconnect"

git clone "https://github.com/KiraCore/tools.git" $TOOLS_DIR
cd $TOOLS_DIR
git checkout main
chmod -R 555 $TOOLS_DIR
FILE_HASH=$(CDHelper hash SHA256 -p="$TOOLS_DIR" -x=true -r=true --silent=true -i="$TOOLS_DIR/.git,$TOOLS_DIR/.gitignore")

echoInfo "INFO: Tools checkout finalized, directory hash: $FILE_HASH"

#TOOLS_EXPECTED_HASH="cbe7369e16260943354ad830607bf9618d7f90acb9f9903ca7dc1d305fc22c6b"
TOOLS_EXPECTED_HASH=""

if [ ! -z "$TOOLS_EXPECTED_HASH" ] && [ "$FILE_HASH" != "$TOOLS_EXPECTED_HASH" ]; then
    echoErr "ERROR: Failed to check integrity hash of the KIRA tools!"
    echoErr "ERROR: Expected hash: $TOOLS_EXPECTED_HASH, but got $FILE_HASH"
    exit 1
fi

cd $KMS_KEYIMPORT_DIR
ls -l /bin/tmkms-key-import || echoWarn "WARNING: tmkms-key-import symlink not found"
rm -fv /bin/tmkms-key-import || echoWarn "WARNING: failed removing old tmkms-key-import symlink"
ln -s $KMS_KEYIMPORT_DIR/start.sh /bin/tmkms-key-import || echoErr "WARNING: tmkms-key-import symlink already exists"

echoInfo "INFO: Navigating to '$PRIV_KEYGEN_DIR' and building priv-key-gen tool..."
cd $PRIV_KEYGEN_DIR
export HOME="$SELF_HOME";
go build
make install

ls -l /bin/priv-key-gen || echoWarn "WARNING: priv-validator-key-gen symlink not found"
rm -fv /bin/priv-key-gen || echoWarn "WARNING: Removing old priv-validator-key-gen symlink"
ln -s $PRIV_KEYGEN_DIR/priv-validator-key-gen /bin/priv-key-gen || echoErr "WARNING: priv-validator-key-gen symlink already exists"

cd $TMCONNECT_DIR
go build
make install
ls -l /bin/tmconnect || echoWarn "WARNING: tmconnect symlink not found"
rm -fv /bin/tmconnect || echoWarn "WARNING: Removing old tmconnect symlink"
ln -s $TMCONNECT_DIR/tmconnect /bin/tmconnect || echoErr "WARNING: tmconnect symlink already exists"
