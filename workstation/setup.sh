#!/bin/bash

SKIP_UPDATE=$1
START_TIME=$2

set +e && source "/etc/profile" &>/dev/null && set -e

set +x
echo "------------------------------------------------"
echo "| STARTED: SETUP                               |"
echo "|-----------------------------------------------"
echo "| SKIP UPDATE: $SKIP_UPDATE"
echo "|  START TIME: $START_TIME"
echo "------------------------------------------------"
set -x

[ -z "$START_TIME" ] && START_TIME="$(date -u +%s)"
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"
cd /kira
UPDATED="False"
if [ "$SKIP_UPDATE" == "False" ]; then
    echo "INFO: Updating kira, Sekai, frontend, INTERX"
    $KIRA_SCRIPTS/git-pull.sh "$FRONTEND_REPO" "$FRONTEND_BRANCH" "$KIRA_FRONTEND" &
    $KIRA_SCRIPTS/git-pull.sh "$INTERX_REPO" "$INTERX_BRANCH" "$KIRA_INTERX" &
    $KIRA_SCRIPTS/git-pull.sh "$SEKAI_REPO" "$SEKAI_BRANCH" "$KIRA_SEKAI" &
    $KIRA_SCRIPTS/git-pull.sh "$INFRA_REPO" "$INFRA_BRANCH" "$KIRA_INFRA" 777 &
    wait < <(jobs -p)

    # we must ensure that recovery files can't be destroyed in the update process and cause a deadlock
    rm -r -f $KIRA_MANAGER
    cp -r $KIRA_WORKSTATION $KIRA_MANAGER
    chmod -R 777 $KIRA_MANAGER

    source $KIRA_WORKSTATION/setup.sh "True" "$START_TIME"
    UPDATED="True"
elif [ "$SKIP_UPDATE" == "True" ]; then
    echo "INFO: Skipping kira Update..."
else
    echo "ERROR: SKIP_UPDATE propoerty is invalid or undefined"
    exit 1
fi

ls -l /bin/kira || echo "WARNING: KIRA Manager symlink not found"
rm /bin/kira || echo "WARNING: Failed to remove old KIRA Manager symlink"
ln -s $KIRA_WORKSTATION/kira/kira.sh /bin/kira || echo "WARNING: KIRA Manager symlink already exists"

$KIRA_WORKSTATION/setup/envs.sh
$KIRA_WORKSTATION/setup/hosts.sh
$KIRA_WORKSTATION/setup/system.sh
$KIRA_WORKSTATION/setup/golang.sh
$KIRA_WORKSTATION/setup/tools.sh
$KIRA_WORKSTATION/setup/systemctl2.sh
$KIRA_WORKSTATION/setup/docker.sh
$KIRA_WORKSTATION/setup/nginx.sh
$KIRA_WORKSTATION/setup/registry.sh

touch /tmp/rs_manager
touch /tmp/rs_git_manager
touch /tmp/rs_container_manager
