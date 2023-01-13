#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup/tools.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

$KIRA_MANAGER/setup/envs.sh

loadGlobEnvs

mkdir -p $KIRA_BIN && cd $KIRA_BIN

BIN_DEST="/usr/local/bin/bash-utils.sh" && \
  safeWget ./bash-utils.sh "https://github.com/KiraCore/tools/releases/download/$(globGet TOOLS_VERSION)/bash-utils.sh" \
  "$(globGet KIRA_COSIGN_PUB)" && chmod -v 755 ./bash-utils.sh && ./bash-utils.sh bashUtilsSetup && chmod -v 755 $BIN_DEST && . /etc/profile

# tmconnect handshake --address="e27b3a9d952f3863eaeb7141114c253edd03905d@167.99.54.200:26656" --node_key="$KIRA_SECRETS/sentry_node_key.json" --timeout=60 --verbose
# tmconnect id --address="167.99.54.200:26656" --node_key="$COMMON_DIR/node_key.json" --timeout=1
# tmconnect network --address="78.46.241.36:36656" --node_key="$KIRA_SECRETS/sentry_node_key.json" --timeout=1
BIN_DEST="/usr/local/bin/tmconnect" && \
  safeWget ./tmconnect.deb "https://github.com/KiraCore/tools/releases/download/$(globGet TOOLS_VERSION)/tmconnect-linux-$(getArch).deb" \
  "$(globGet KIRA_COSIGN_PUB)" && dpkg-deb -x ./tmconnect.deb ./tmconnect && cp -fv "$KIRA_BIN/tmconnect/bin/tmconnect" $BIN_DEST && chmod -v 755 $BIN_DEST

# validator-key-gen --mnemonic="$MNEMONIC" --valkey=./priv_validator_key.json --nodekey=./node_key.json --keyid=./node_id.key
BIN_DEST="/usr/local/bin/validator-key-gen" && \
  safeWget ./validator-key-gen.deb "https://github.com/KiraCore/tools/releases/download/$(globGet TOOLS_VERSION)/validator-key-gen-linux-$(getArch).deb" \
  "$(globGet KIRA_COSIGN_PUB)" && dpkg-deb -x ./validator-key-gen.deb ./validator-key-gen && \
   cp -fv "$KIRA_BIN/validator-key-gen/bin/validator-key-gen" $BIN_DEST && chmod -v 755 $BIN_DEST

# tmkms-key-import "$MNEMONIC" "$HOME/priv_validator_key.json" "$HOME/signing.key" "$HOME/node_key.json" "$HOME/node_id.key"
BIN_DEST="/usr/local/bin/tmkms-key-import" && \
  safeWget ./tmkms-key-import "https://github.com/KiraCore/tools/releases/download/$(globGet TOOLS_VERSION)/tmkms-key-import-linux-$(getArch)" \
  "$(globGet KIRA_COSIGN_PUB)" && cp -fv "$KIRA_BIN/tmkms-key-import" $BIN_DEST && chmod -v 755 $BIN_DEST

BIN_DEST="/usr/local/bin/bip39gen" && \
  safeWget ./bip39gen.deb "https://github.com/KiraCore/tools/releases/download/$(globGet TOOLS_VERSION)/bip39gen-linux-$(getArch).deb" \
  "$(globGet KIRA_COSIGN_PUB)" && dpkg-deb -x ./bip39gen.deb ./bip39gen && cp -fv "$KIRA_BIN/bip39gen/bin/bip39gen" $BIN_DEST && chmod -v 755 $BIN_DEST

# SYSCTRL_BOOTED="true"
# systemctl daemon-reload || SYSCTRL_BOOTED="false"
# if [ "${SYSCTRL_BOOTED,,}" != "true" ] ; then
#     BIN_DEST=/usr/bin/systemctl
#     safeWget $BIN_DEST \
#         https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/9cbe1a00eb4bdac6ff05b96ca34ec9ed3d8fc06c/files/docker/systemctl.py \
#         "e02e90c6de6cd68062dadcc6a20078c34b19582be0baf93ffa7d41f5ef0a1fdd"
# 
#   chmod 555 $BIN_DEST
# fi

echoInfo "INFO:        Installed bash-utils: " && bashUtilsVersion
echoInfo "INFO:         Installed tmconnect: " && tmconnect version
echoInfo "INFO: Installed validator-key-gen: " && validator-key-gen --version
echoInfo "INFO:  Installed tmkms-key-import: " && tmkms-key-import version
echoInfo "INFO:          Installed bip39gen: " && bip39gen version
echoInfo "INFO:            Booted systemctl: " && systemctl --version
  
cd $KIRA_HOME