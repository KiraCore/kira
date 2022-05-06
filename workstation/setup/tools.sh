#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/tools.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

$KIRA_MANAGER/setup/envs.sh

loadGlobEnvs

mkdir -p $KIRA_BIN && cd $KIRA_BIN

BIN_DEST="/usr/local/bin/bash-utils.sh" && \
  safeWget ./bash-utils.sh "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/bash-utils.sh" \
  "$KIRA_COSIGN_PUB" && chmod -v 755 ./bash-utils.sh && ./bash-utils.sh bashUtilsSetup && chmod -v 755 $BIN_DEST && . /etc/profile

BIN_DEST="/usr/local/bin/CDHelper" && \
  safeWget ./cdhelper.zip "https://github.com/asmodat/CDHelper/releases/download/$CDHELPER_VERSION/CDHelper-linux-$(getArch).zip" \
  "c2e40c7143f4097c59676f037ac6eaec68761d965bd958889299ab32f1bed6b3,082e05210f93036e0008658b6c6bd37ab055bac919865015124a0d72e18a45b7" && \
  unzip -o ./cdhelper.zip -d "CDHelper" && cp -rfv ./CDHelper "$(dirname $BIN_DEST)" && chmod -Rv 755 $BIN_DEST && setGlobPath "$BIN_DEST"

# tmconnect handshake --address="e27b3a9d952f3863eaeb7141114c253edd03905d@167.99.54.200:26656" --node_key="$KIRA_SECRETS/sentry_node_key.json" --timeout=60 --verbose
# tmconnect id --address="167.99.54.200:26656" --node_key="$COMMON_DIR/node_key.json" --timeout=1
# tmconnect network --address="78.46.241.36:36656" --node_key="$KIRA_SECRETS/sentry_node_key.json" --timeout=1
BIN_DEST="/usr/local/bin/tmconnect" && \
  safeWget ./tmconnect.deb "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/tmconnect-linux-$(getArch).deb" \
  "$KIRA_COSIGN_PUB" && dpkg-deb -x ./tmconnect.deb ./tmconnect && cp -fv "$KIRA_BIN/tmconnect/bin/tmconnect" $BIN_DEST && chmod -v 755 $BIN_DEST

# validator-key-gen --mnemonic="$MNEMONIC" --valkey=./priv_validator_key.json --nodekey=./node_key.json --keyid=./node_id.key
BIN_DEST="/usr/local/bin/validator-key-gen" && \
  safeWget ./validator-key-gen.deb "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/validator-key-gen-linux-$(getArch).deb" \
  "$KIRA_COSIGN_PUB" && dpkg-deb -x ./validator-key-gen.deb ./validator-key-gen && \
   cp -fv "$KIRA_BIN/validator-key-gen/bin/validator-key-gen" $BIN_DEST && chmod -v 755 $BIN_DEST

# tmkms-key-import "$MNEMONIC" "$HOME/priv_validator_key.json" "$HOME/signing.key" "$HOME/node_key.json" "$HOME/node_id.key"
BIN_DEST="/usr/local/bin/tmkms-key-import" && \
  safeWget ./tmkms-key-import "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/tmkms-key-import-linux-$(getArch)" \
  "$KIRA_COSIGN_PUB" && cp -fv "$KIRA_BIN/tmkms-key-import" $BIN_DEST && chmod -v 755 $BIN_DEST

BIN_DEST="/usr/local/bin/bip39gen" && \
  safeWget ./bip39gen.deb "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/bip39gen-linux-$(getArch).deb" \
  "$KIRA_COSIGN_PUB" && dpkg-deb -x ./bip39gen.deb ./bip39gen && cp -fv "$KIRA_BIN/bip39gen/bin/bip39gen" $BIN_DEST && chmod -v 755 $BIN_DEST

echoInfo "INFO:          Installed CDHelper: " && CDHelper version
echoInfo "INFO:        Installed bash-utils: " && bashUtilsVersion
echoInfo "INFO:         Installed tmconnect: " && tmconnect version
echoInfo "INFO: Installed validator-key-gen: " && validator-key-gen --version
echoInfo "INFO:  Installed tmkms-key-import: " && tmkms-key-import version
echoInfo "INFO:          Installed bip39gen: " && bip39gen version

    cat > /etc/systemd/system/kirascan.service << EOL
[Unit]
Description=KIRA Console UI Monitoring Service
After=network.target
[Service]
CPUWeight=100
CPUQuota=100%
IOWeight=100
MemorySwapMax=0
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

    cat > /etc/systemd/system/kiraclean.service << EOL
[Unit]
Description=KIRA Cleanup Service
After=network.target
[Service]
CPUWeight=5
CPUQuota=5%
IOWeight=5
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/kira/cleanup.sh
Restart=always
RestartSec=30
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

SYSCTRL_BOOTED="true"
systemctl daemon-reload || SYSCTRL_BOOTED="false"

if [ "${SYSCTRL_BOOTED,,}" != "true" ] ; then
  BIN_DEST=/usr/bin/systemctl
  safeWget $BIN_DEST \
   https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/9cbe1a00eb4bdac6ff05b96ca34ec9ed3d8fc06c/files/docker/systemctl.py \
   "e02e90c6de6cd68062dadcc6a20078c34b19582be0baf93ffa7d41f5ef0a1fdd"

  chmod 555 $BIN_DEST
else
  echoInfo "INFO:            Booted systemctl: " && systemctl --version
fi

systemctl daemon-reload
systemctl enable kirascan
systemctl enable kiraclean
systemctl restart kirascan || echoWarn "WARNING: Failed to restart KIRA scan service"
systemctl restart kiraclean || echoWarn "WARNING: Failed to restart KIRA cleanup service"
  
cd $KIRA_HOME