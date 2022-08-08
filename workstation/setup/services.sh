#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echoInfo "INFO: Updating kira update service..."
cat > /etc/systemd/system/kiraup.service << EOL
[Unit]
Description=KIRA Update And Setup Service
After=network.target
[Service]
CPUWeight=20
CPUQuota=85%
IOWeight=20
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/update.sh
Restart=always
SuccessExitStatus=on-failure
RestartSec=5
LimitNOFILE=4096
StandardOutput=append:$KIRA_LOGS/kiraup.log
StandardError=append:$KIRA_LOGS/kiraup.log
[Install]
WantedBy=default.target
EOL

echoInfo "INFO: Updating kira upgrade plan service..."
cat > /etc/systemd/system/kiraplan.service << EOL
[Unit]
Description=KIRA Upgrade Plan Service
After=network.target
[Service]
CPUWeight=100
CPUQuota=100%
IOWeight=100
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/plan.sh
Restart=always
SuccessExitStatus=on-failure
RestartSec=5
LimitNOFILE=4096
StandardOutput=append:$KIRA_LOGS/kiraplan.log
StandardError=append:$KIRA_LOGS/kiraplan.log
[Install]
WantedBy=default.target
EOL