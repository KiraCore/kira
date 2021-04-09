#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
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
    echoInfo "INFO: Updating kira, Sekai, frontend, INTERX"
    $KIRA_SCRIPTS/git-pull.sh "$FRONTEND_REPO" "$FRONTEND_BRANCH" "$KIRA_FRONTEND" &
    $KIRA_SCRIPTS/git-pull.sh "$INTERX_REPO" "$INTERX_BRANCH" "$KIRA_INTERX" &
    $KIRA_SCRIPTS/git-pull.sh "$SEKAI_REPO" "$SEKAI_BRANCH" "$KIRA_SEKAI" &
    $KIRA_SCRIPTS/git-pull.sh "$INFRA_REPO" "$INFRA_BRANCH" "$KIRA_INFRA" 555 &
    wait < <(jobs -p)

    # we must ensure that recovery files can't be destroyed in the update process and cause a deadlock
    rm -rfv "$KIRA_MANAGER" && mkdir -p "$KIRA_MANAGER"
    cp -rfv "$KIRA_WORKSTATION/." "$KIRA_MANAGER"
    chmod -R 555 $KIRA_MANAGER

    source $KIRA_MANAGER/setup.sh "true" "$START_TIME"
elif [ "${SKIP_UPDATE,,}" == "true" ]; then
    echoInfo "INFO: Skipping kira Update..."
else
    echoErr "ERROR: SKIP_UPDATE propoerty is invalid or undefined"
    exit 1
fi

ls -l /bin/kira || echoWarn "WARNING: KIRA Manager symlink not found"
rm /bin/kira || echoWarn "WARNING: Failed to remove old KIRA Manager symlink"
ln -s $KIRA_MANAGER/kira/kira.sh /bin/kira || echo "WARNING: KIRA Manager symlink already exists"

systemctl stop docker || echoErr "ERROR: Failed to stop docker service"
systemctl stop kirascan  || echoErr "ERROR: Failed to stop kirascan service"

$KIRA_MANAGER/setup/envs.sh
$KIRA_MANAGER/setup/network.sh
$KIRA_MANAGER/setup/system.sh
$KIRA_MANAGER/setup/golang.sh
$KIRA_MANAGER/setup/tools.sh
$KIRA_MANAGER/setup/docker.sh
$KIRA_MANAGER/setup/nginx.sh
$KIRA_MANAGER/setup/registry.sh

touch /tmp/rs_manager
touch /tmp/rs_git_manager
touch /tmp/rs_container_manager

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: SETUP SCRIPT                       |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
