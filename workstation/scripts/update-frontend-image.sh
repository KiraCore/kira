#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

FRONTEND_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_FRONTEND)
FRONTEND_INTEGRITY="${FRONTEND_BRANCH}_${FRONTEND_HASH}"

FRONTEND_IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$FRONTEND_INTEGRITY" || echo "error")
if [ "$FRONTEND_IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting frontend image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$FRONTEND_INTEGRITY" "REPO=$FRONTEND_REPO" "BRANCH=$FRONTEND_BRANCH" #4
elif [ "$FRONTEND_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: frontend image is up to date"
else
    echo "ERROR: Failed to test if frontend image exists"
    exit 1
fi
