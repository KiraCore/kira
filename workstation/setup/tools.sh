#!/bin/bash

exec 2>&1
set -e

ETC_PROFILE="/etc/profile"
source $ETC_PROFILE &>/dev/null

KIRA_SETUP_BASE_TOOLS="$KIRA_SETUP/base-tools-v0.0.8"
if [ ! -f "$KIRA_SETUP_BASE_TOOLS" ]; then
  echo "INFO: Update and Intall basic tools and dependencies..."
  apt-get update -y --fix-missing
  apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    python \
    python3 \
    python3-pip \
    software-properties-common \
    tar \
    zip

  # https://linuxhint.com/install_aws_cli_ubuntu/
  aws --version
  touch $KIRA_SETUP_BASE_TOOLS

  #allow to execute scripts just like .exe files with double click
  gsettings set org.gnome.nautilus.preferences executable-text-activation 'launch'
else
  echo "INFO: Base tools were already installed."
fi
