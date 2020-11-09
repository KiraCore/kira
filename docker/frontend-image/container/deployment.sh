#!/bin/bash

exec 2>&1
set -e
set -x

# Local Update
# (rm -fv $KIRA_INFRA/docker/tools-image/container/deployment.sh) && nano $KIRA_INFRA/docker/tools-image/container/deployment.sh

apt-get update -y --fix-missing

echo "Intalling NPM..."
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    npm
npm install -g n
n stable

echo "APT Intall Rust Dependencies..."
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    libc6-dev \
    libbz2-dev \
    libcurl4-openssl-dev \
    libdb-dev \
    libevent-dev \
    libffi-dev \
    libgdbm-dev \
    libglib2.0-dev \
    libgmp-dev \
    libjpeg-dev \
    libkrb5-dev \
    liblzma-dev \
    libmagickcore-dev \
    libmagickwand-dev \
    libmaxminddb-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libpng-dev \
    libpq-dev \
    libreadline-dev \
    libsqlite3-dev \
    libwebp-dev \
    libxml2-dev \
    libxslt-dev \
    libyaml-dev \
    xz-utils \
    zlib1g-dev

echo "APT Intall Essential Dependencies..."
apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    expect \
    hxtools

echo "Creating GIT simlink and global setup"
ln -s /usr/bin/git /bin/git || echo "git symlink already exists"

which git
/usr/bin/git --version

echo "Installing .NET"
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-runtime-deps-3.1
apt-get install -y dotnet-runtime-3.1
apt-get install -y aspnetcore-runtime-3.1
apt-get install -y dotnet-sdk-3.1

echo "Installing latest go version $GO_VERSION https://golang.org/doc/install ..."
wget https://dl.google.com/go/go$GO_VERSION.linux-amd64.tar.gz
tar -C /usr/local -xvf go$GO_VERSION.linux-amd64.tar.gz
go version
go env

echo "Installing custom systemctl..."
wget https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl.py -O /usr/local/bin/systemctl2
chmod -v 777 /usr/local/bin/systemctl2

systemctl2 --version

echo "NGINX Setup..."

cat > $NGINX_CONFIG << EOL
worker_processes 1;
events { worker_connections 512; }
http { 
#server{} 
}
#EOF
EOL

mkdir -v $NGINX_SERVICED_PATH
printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > $NGINX_SERVICED_PATH/override.conf

systemctl2 enable nginx.service

echo "Install Asmodat Automation helper tools"
${SELF_SCRIPTS}/cdhelper-update.sh "v0.6.13"
CDHelper version

${SELF_SCRIPTS}/awshelper-update.sh "v0.12.4"
AWSHelper version

echo "INFO: Allow many open files..."
CDHelper text lineswap --insert="* hard nofile 999999" --prefix="* hard nofile" --path="/etc/security/limits.conf" --append-if-found-not=True
CDHelper text lineswap --insert="* soft nofile 999999" --prefix="* soft nofile" --path="/etc/security/limits.conf" --append-if-found-not=True

echo "grpcurl install..."
GRPCURL_VERSION="1.7.0"
GRPCURL_PATH="${GOPATH}/src/github.com/fullstorydev/grpcurl"
mkdir -p $GRPCURL_PATH
cd $GRPCURL_PATH
wget "https://github.com/fullstorydev/grpcurl/archive/v${GRPCURL_VERSION}.tar.gz"
tar -zxvf ./v$GRPCURL_VERSION.tar.gz
cd ./grpcurl-$GRPCURL_VERSION/cmd/grpcurl/
go build
ln -s $GRPCURL_PATH/grpcurl-$GRPCURL_VERSION/cmd/grpcurl/grpcurl /bin/grpcurl

printenv

