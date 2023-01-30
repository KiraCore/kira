#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

mkdir -p $KIRA_LOGS
touch $KIRA_LOGS/kiraup.log $KIRA_LOGS/kiraplan.log $KIRA_LOGS/kiraclean.log $KIRA_LOGS/kirascan.log $KIRA_LOGS/docker.log
chmod +rw -v $KIRA_LOGS/kiraup.log $KIRA_LOGS/kiraplan.log $KIRA_LOGS/kiraclean.log $KIRA_LOGS/kirascan.log $KIRA_LOGS/docker.log
echo -n "" > $KIRA_LOGS/kiraup.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraup.log'"
echo -n "" > $KIRA_LOGS/kiraplan.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraplan.log'"
echo -n "" > $KIRA_LOGS/kiraclean.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraclean.log'"
echo -n "" > $KIRA_LOGS/kirascan.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kirascan.log'"
echo -n "" > $KIRA_LOGS/docker.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/docker.log'"

# systemctl restart kiraup && journalctl -u kiraup -f --output cat
# cat $KIRA_LOGS/kiraup.log
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
WorkingDirectory=$(globGet KIRA_HOME)
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

# systemctl restart kiraplan && journalctl -u kiraplan -f --output cat
# cat $KIRA_LOGS/kiraplan.log
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
WorkingDirectory=$(globGet KIRA_HOME)
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

# systemctl restart kirascan && journalctl -u kirascan -f --output cat
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
WorkingDirectory=$(globGet KIRA_HOME)
ExecStart=/bin/bash $KIRA_MANAGER/kira/monitor.sh
StandardOutput=append:$KIRA_LOGS/kirascan.log
StandardError=append:$KIRA_LOGS/kirascan.log
Restart=always
SuccessExitStatus=on-failure
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

# systemctl restart kiraclean && journalctl -u kiraclean -f --output cat
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
WorkingDirectory=$(globGet KIRA_HOME)
ExecStart=/bin/bash $KIRA_MANAGER/kira/cleanup.sh
StandardOutput=append:$KIRA_LOGS/kiraclean.log
StandardError=append:$KIRA_LOGS/kiraclean.log
Restart=always
SuccessExitStatus=on-failure
RestartSec=30
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL

echoInfo "INFO: Systemctl version: "
systemctl --version

systemctl daemon-reload
systemctl enable kirascan
systemctl enable kiraclean
systemctl restart kirascan || echoWarn "WARNING: Failed to restart KIRA scan service"
systemctl restart kiraclean || echoWarn "WARNING: Failed to restart KIRA cleanup service"
