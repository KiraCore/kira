#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="${SEKAI_BRANCH}_${SEKAI_HASH}"

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/kira" "kira" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "${IMAGE_EXISTS,,}" == "false" ]; then
    echo "All imags were updated, starting kira image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/kira" "kira" "latest" "$SEKAI_INTEGRITY" "REPO=$SEKAI_REPO" "BRANCH=$SEKAI_BRANCH" #4
elif [ "${IMAGE_EXISTS,,}" == "true" ]; then
    echo "INFO: kira-image is up to date"
else
    echo "ERROR: Failed to test if kira image exists or not: '$IMAGE_EXISTS'"
    exit 1
fi
