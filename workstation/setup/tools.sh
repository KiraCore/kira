#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &>/dev/null

KIRA_SETUP_BASE_TOOLS="$KIRA_SETUP/base-tools-v0.1.0"
if [ ! -f "$KIRA_SETUP_BASE_TOOLS" ]; then
  echo "INFO: Update and Intall basic tools and dependencies..."
  apt-get update -y --fix-missing
  apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    hashdeep \
    nginx \
    python \
    python3 \
    python3-pip \
    software-properties-common \
    tar \
    zip \
    nodejs

  apt update
  apt install nodejs
  nodejs -v
  apt install npm
  npm -v

  npm install -g bip39-cli

  touch $KIRA_SETUP_BASE_TOOLS

else
  echo "INFO: Base tools were already installed."
fi
