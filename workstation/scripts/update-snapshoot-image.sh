#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="${SEKAI_BRANCH}_${SEKAI_HASH}"

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/snapshoot" "snapshoot" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "$IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting snapshoot image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/snapshoot" "snapshoot" "latest" "$SEKAI_INTEGRITY" "REPO=$SEKAI_REPO" "BRANCH=$SEKAI_BRANCH"
elif [ "$IMAGE_EXISTS" == "True" ]; then
    echo "INFO: snapshoot-image is up to date"
else
    echo "ERROR: Failed to test if snapshoot image exists"
    exit 1
fi
