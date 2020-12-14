#!/bin/bash
set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

exec &> >(tee -a "$KIRA_DUMP/setup.log")

KIRA_SETUP_BASE_TOOLS="$KIRA_SETUP/base-tools-v0.1.6"
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
    jq \
    php-cli \
    unzip \
    php7.4-gmp \
    php-mbstring

  cd /home/$SUDO_USER
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer

  git clone https://github.com/dan-da/hd-wallet-derive.git
  cd hd-wallet-derive
  yes "yes" | composer install

  cd /home/$SUDO_USER
  touch $KIRA_SETUP_BASE_TOOLS

else
  echo "INFO: Base tools were already installed."
fi
