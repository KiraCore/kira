#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="_${SEKAI_HASH}"

FRONTEND_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "$FRONTEND_IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting frontend image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$SEKAI_INTEGRITY" "REPO=$FRONTEND_REPO" "BRANCH=dev" #4
elif [ "$FRONTEND_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: frontend image is up to date"
else
    echo "ERROR: Failed to test if frontend image exists"
    exit 1
fi
