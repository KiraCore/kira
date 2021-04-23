#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/setup/tools.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

ESSENTIALS_HASH=$(echo "$KIRA_HOME-1" | md5sum | awk '{ print $1 }' || echo -n "")
SETUP_CHECK="$KIRA_SETUP/base-tools-1-$ESSENTIALS_HASH"
if [ ! -f "$SETUP_CHECK" ]; then
    echoInfo "INFO: Update and Intall basic tools and dependencies..."
    apt-get update -y --fix-missing
    apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
      python python3 python3-pip software-properties-common tar jq php-cli zip unzip p7zip-full \
      php7.4-gmp php-mbstring md5deep sysstat htop ccze
  
    # tools required to execute: perf top --sort comm,dso
    apt-get install -y linux-tools-common linux-tools-generic linux-tools-`uname -r` || echoErr "ERROR: Failed to install monitoring tools"
  
    pip3 install ECPy
  
    # jar extraction tool is essential for large file unzip
    apt install -y default-jre default-jdk 
  
    cd $KIRA_HOME
    export COMPOSER_HOME="$KIRA_HOME/.config/composer";
    echoInfo "INFO: Composer home: $COMPOSER_HOME"
    curl -sS https://getcomposer.org/installer -o composer-setup.php
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  
    HD_WALLET_DIR="$KIRA_HOME/hd-wallet-derive"
    HD_WALLET_PATH="$HD_WALLET_DIR/hd-wallet-derive.php"
    $KIRA_SCRIPTS/git-pull.sh "https://github.com/KiraCore/hd-wallet-derive.git" "master" "$HD_WALLET_DIR" 555 "" "$HD_WALLET_DIR/tests,$HD_WALLET_DIR/vendor"
    FILE_HASH=$(CDHelper hash SHA256 -p="$HD_WALLET_DIR" -x=true -r=true --silent=true -i="$HD_WALLET_DIR/.git,$HD_WALLET_DIR/.gitignore,$HD_WALLET_DIR/tests,$HD_WALLET_DIR/vendor")
    EXPECTED_HASH="078da5d02f80e96fae851db9d2891d626437378dd43d1d647658526b9c807fcd"
  
    if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
        echoWarn "WARNING: Failed to check integrity hash of the hd-wallet derivaiton tool !!!"
        echoErr "ERROR: Expected hash: $EXPECTED_HASH, but got $FILE_HASH"
        exit 1
    fi
  
    cd $HD_WALLET_DIR
    yes "yes" | composer install
  
    ls -l /bin/hd-wallet-derive || echoWarn "WARNING: Wallet Derive Tool was not found"
    rm /bin/hd-wallet-derive || echoWarn "WARNING: Failed to remove old Wallet Derive symlink"
    ln -s $HD_WALLET_PATH /bin/hd-wallet-derive || echoWarn "WARNING: KIRA Manager symlink already exists"
  
    cd $KIRA_HOME
    TOOLS_DIR="$KIRA_HOME/tools"
    KMS_KEYIMPORT_DIR="$TOOLS_DIR/tmkms-key-import"
    PRIV_KEYGEN_DIR="$TOOLS_DIR/priv-validator-key-gen"
    $KIRA_SCRIPTS/git-pull.sh "https://github.com/KiraCore/tools.git" "main" "$TOOLS_DIR" 555
    FILE_HASH=$(CDHelper hash SHA256 -p="$TOOLS_DIR" -x=true -r=true --silent=true -i="$TOOLS_DIR/.git,$TOOLS_DIR/.gitignore")
    EXPECTED_HASH="0a03a0d0b760c80c14bef5f0c1ac2c7290361370b394697f4c7ad711ca5c998c"
  
    if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
        echoWarn "WARNING: Failed to check integrity hash of the kira tools !!!"
        echoErr "ERROR: Expected hash: $EXPECTED_HASH, but got $FILE_HASH"
        exit 1
    fi
  
    cd $KMS_KEYIMPORT_DIR
    ls -l /bin/tmkms-key-import || echoWarn "WARNING: tmkms-key-import symlink not found"
    rm /bin/tmkms-key-import || echoWarn "WARNING: failed removing old tmkms-key-import symlink"
    ln -s $KMS_KEYIMPORT_DIR/start.sh /bin/tmkms-key-import || echoErr "WARNING: tmkms-key-import symlink already exists"

    echoInfo "INFO: Navigating to '$PRIV_KEYGEN_DIR' and building priv-key-gen tool..."
    cd $PRIV_KEYGEN_DIR
    export HOME="$KIRA_HOME";
    go build
    make install
  
    ls -l /bin/priv-key-gen || echoWarn "WARNING: priv-validator-key-gen symlink not found"
    rm /bin/priv-key-gen || echoWarn "WARNING: Removing old priv-validator-key-gen symlink"
    ln -s $PRIV_KEYGEN_DIR/priv-validator-key-gen /bin/priv-key-gen || echoErr "WARNING: priv-validator-key-gen symlink already exists"

    # MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic' | tr -d '"')
    # tmkms-key-import "$MNEMONIC" "$HOME/priv_validator_key.json" "$HOME/signing.key" "$HOME/node_key.json" "$HOME/node_id.key"
    # priv-key-gen --mnemonic="$MNEMONIC" --valkey=./priv_validator_key.json --nodekey=./node_key.json --keyid=./node_id.key

    cat > /etc/systemd/system/kirascan.service << EOL
[Unit]
Description=Kira Console UI Monitoring Service
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/kira/monitor.sh
Restart=always
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

    systemctl daemon-reload
    systemctl enable kirascan
    systemctl restart kirascan
  
    cd $KIRA_HOME
    touch $SETUP_CHECK
else
    echoInfo "INFO: Base tools were already installed."
fi
