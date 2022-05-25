#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SKIP_UPDATE=$1
START_TIME=$2

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: SETUP                               |"
echoWarn "|-----------------------------------------------"
echoWarn "| SKIP UPDATE: $SKIP_UPDATE"
echoWarn "|  START TIME: $START_TIME"
echoWarn "------------------------------------------------"
set -x

[ -z "$START_TIME" ] && START_TIME="$(date -u +%s)"
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="false"
cd /kira

if [ "${SKIP_UPDATE,,}" == "false" ] || [ ! -d "$KIRA_MANAGER" ] ; then
    echoInfo "INFO: Updating kira, sekai, INTERX"
    $KIRA_SCRIPTS/git-pull.sh "$INTERX_REPO" "$INTERX_BRANCH" "$KIRA_INTERX" &
    $KIRA_SCRIPTS/git-pull.sh "$SEKAI_REPO" "$SEKAI_BRANCH" "$KIRA_SEKAI" &
    $KIRA_SCRIPTS/git-pull.sh "$INFRA_REPO" "$INFRA_BRANCH" "$KIRA_INFRA" 555 &
    wait < <(jobs -p)

    # we must ensure that recovery files can't be destroyed in the update process and cause a deadlock
    rm -rfv "$KIRA_MANAGER" && mkdir -p "$KIRA_MANAGER"
    cp -rfv "$KIRA_WORKSTATION/." "$KIRA_MANAGER"
    chmod -R 555 $KIRA_MANAGER

    echoInfo "INFO: Restarting setup and skipping update..."
    $KIRA_MANAGER/setup.sh "true" "$START_TIME"
    exit 0
elif [ "${SKIP_UPDATE,,}" == "true" ]; then
    echoInfo "INFO: Skipping kira Update..."
else
    echoErr "ERROR: SKIP_UPDATE propoerty is invalid or undefined"
    exit 1
fi

echoInfo "INFO: Please wait, starting setup..."
ls -l /bin/kira || echoWarn "WARNING: KIRA Manager symlink not found"
rm /bin/kira || echoWarn "WARNING: Failed to remove old KIRA Manager symlink"
ln -s $KIRA_MANAGER/kira/kira.sh /bin/kira || echo "WARNING: KIRA Manager symlink already exists"

$KIRA_MANAGER/kira/containers-pkill.sh "true" "stop"
$KIRA_SCRIPTS/docker-stop.sh || echoErr "ERROR: Failed to stop docker service"
timeout 60 systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"

$KIRA_MANAGER/setup/envs.sh
$KIRA_MANAGER/setup/network.sh
$KIRA_MANAGER/setup/system.sh
$KIRA_MANAGER/setup/tools.sh
$KIRA_MANAGER/setup/docker.sh

$KIRA_SCRIPTS/docker-restart.sh
# echoInfo "INFO: Waiting for all containers to start..."
# sleep 120
# $KIRA_MANAGER/setup/registry.sh

echoInfo "INFO: Updating kira update service..."
cat > /etc/systemd/system/kiraup.service << EOL
[Unit]
Description=KIRA Update And Setup Service
After=network.target
[Service]
CPUWeight=100
CPUQuota=100%
IOWeight=100
MemorySwapMax=0
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/update.sh
Restart=always
SuccessExitStatus=on-failure
RestartSec=5
LimitNOFILE=4096
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
[Install]
WantedBy=default.target
EOL

touch /tmp/rs_manager /tmp/rs_git_manager /tmp/rs_container_manager

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SETUP SCRIPT                       |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
#