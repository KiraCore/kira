#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/setup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

declare -l SKIP_UPDATE=$1
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

if [ "$SKIP_UPDATE" == "false" ] || [ ! -d "$KIRA_MANAGER" ] ; then
    echoInfo "INFO: Updating kira, sekai, INTERX"

    safeWget ./kira.zip "$(globGet INFRA_SRC)" "$(globGet KIRA_COSIGN_PUB)" --timeout="300" --tries="3"
    rm -rfv $KIRA_INFRA && mkdir -p $KIRA_INFRA
    unzip ./kira.zip -d $KIRA_INFRA
    rm -rfv ./kira.zip
    chmod -R 555 $KIRA_INFRA

    # update old processes
    rm -rfv $KIRA_MANAGER && mkdir -p $KIRA_MANAGER
    cp -rfv "$KIRA_WORKSTATION/." $KIRA_MANAGER
    chmod -R 555 $KIRA_MANAGER

    echoInfo "INFO: Restarting setup and skipping update..."
    $KIRA_MANAGER/setup.sh "true" "$START_TIME"
    exit 0
elif [ "$SKIP_UPDATE" == "true" ]; then
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
$KIRA_COMMON/docker-stop.sh || echoErr "ERROR: Failed to stop docker service"
timeout 60 systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"

$KIRA_MANAGER/setup/envs.sh
$KIRA_MANAGER/setup/network.sh
$KIRA_MANAGER/setup/system.sh
$KIRA_MANAGER/setup/tools.sh
$KIRA_MANAGER/setup/docker.sh
$KIRA_MANAGER/setup/services.sh
$KIRA_COMMON/docker-restart.sh

touch /tmp/rs_manager /tmp/rs_git_manager /tmp/rs_container_manager

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SETUP SCRIPT                       |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
#