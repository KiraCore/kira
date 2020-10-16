#!/bin/bash

sudo -s

# install essential packages and variables
echo "INFO: Installing Essential Packages and Variables..."
apt-get update -y >/dev/null
apt-get install -y curl >/dev/null

# install basic tools
echo "INFO: Update and Intall basic tools and dependencies..."

# install npm & node
echo "INFO: Intalling NPM..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash >/dev/null
source ~/.bashrc
nvm install v12.18.1 >/dev/null
node -v

# install git
echo "INFO: Intalling Git..."
apt-get install git -y >/dev/null

# install docker
echo "INFO: Intalling Docker..."
apt-get update -y >/dev/null
apt install docker.io -y >/dev/null
systemctl enable --now docker
docker -v

# install and config nginx
echo "INFO: Intalling Nginx..."
apt-get install -y nginx >/dev/null

# Download and install kira management tool
echo "INFO: Installing kira management tool..."

cd /home/$SUDO_USER &&
  rm -f ./kira.sh &&
  wget <URL_TO_THE_SCRIPT >-O ./kira.sh &&
  chmod 555 ./kira.sh &&
  echo "<SHA_256_CHECKSUM> kira.sh" | sha256sum --check

# Add kira management tool to your path
mv kira.sh ~/bin/
