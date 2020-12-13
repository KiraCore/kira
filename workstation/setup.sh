#!/bin/bash

SKIP_UPDATE=$1
START_TIME=$2
INIT_HASH=$3

set +e # prevent potential infinite loop
source "/etc/profile" &>/dev/null
set -e

SETUP_LOG="$KIRA_DUMP/setup.log"

if [ "$SKIP_UPDATE" == "False" ]; then
   exec &> >(tee "$SETUP_LOG")
else
   exec &> >(tee -a "$SETUP_LOG")
fi

set +x
echo "------------------------------------------------"
echo "| STARTED: SETUP                               |"
echo "|-----------------------------------------------"
echo "| SKIP UPDATE: $SKIP_UPDATE"
echo "|  START TIME: $START_TIME"
echo "|   INIT HASH: $INIT_HASH"
echo "|   SETUP LOG: $SETUP_LOG"
echo "------------------------------------------------"
set -x

[ -z "$START_TIME" ] && START_TIME="$(date -u +%s)"
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

[ -z "$DEBUG_MODE" ] && DEBUG_MODE="False"
[ -z "$INIT_HASH" ] && INIT_HASH=$(CDHelper hash SHA256 -p="$KIRA_MANAGER/init.sh" --silent=true || echo "")

cd /kira
UPDATED="False"
if [ "$SKIP_UPDATE" == "False" ]; then
    echo "INFO: Updating kira, Sekai, frontend, INTERX, kms"
    $KIRA_SCRIPTS/git-pull.sh "$FRONTEND_REPO" "$FRONTEND_BRANCH" "$KIRA_FRONTEND" &
    $KIRA_SCRIPTS/git-pull.sh "$INTERX_REPO" "$INTERX_BRANCH" "$KIRA_INTERX" &
    $KIRA_SCRIPTS/git-pull.sh "$KMS_REPO" "$KMS_BRANCH" "$KIRA_KMS" &
    $KIRA_SCRIPTS/git-pull.sh "$SEKAI_REPO" "$SEKAI_BRANCH" "$KIRA_SEKAI" &
    $KIRA_SCRIPTS/git-pull.sh "$INFRA_REPO" "$INFRA_BRANCH" "$KIRA_INFRA" 777 &
    wait < <(jobs -p)

    # we must ensure that recovery files can't be destroyed in the update process and cause a deadlock
    rm -r -f $KIRA_MANAGER
    cp -r $KIRA_WORKSTATION $KIRA_MANAGER
    chmod -R 777 $KIRA_MANAGER

    source $KIRA_WORKSTATION/setup.sh "True" "$START_TIME" "$INIT_HASH"
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

$KIRA_SCRIPTS/cdhelper-update.sh "v0.6.13"

NEW_INIT_HASH=$(CDHelper hash SHA256 -p="$KIRA_WORKSTATION/init.sh" --silent=true)

if [ "$UPDATED" == "True" ] && [ "$NEW_INIT_HASH" != "$INIT_HASH" ]; then
    INTERACTIVE="False"
    echo "WARNING: Hash of the init file changed, full reset is required, starting INIT process..."
    source $KIRA_MANAGER/init.sh "False" "$START_TIME" "$DEBUG_MODE" "$INTERACTIVE"
    echo "INFO: Non-interactive init was finalized"
    sleep 3
    exit 0
fi

$KIRA_WORKSTATION/setup/envs.sh
$KIRA_WORKSTATION/setup/hosts.sh
$KIRA_WORKSTATION/setup/system.sh
$KIRA_WORKSTATION/setup/tools.sh
$KIRA_WORKSTATION/setup/systemctl2.sh
$KIRA_WORKSTATION/setup/docker.sh
$KIRA_WORKSTATION/setup/nginx.sh
$KIRA_WORKSTATION/setup/registry.sh

touch /tmp/rs_manager
touch /tmp/rs_git_manager
touch /tmp/rs_container_manager
