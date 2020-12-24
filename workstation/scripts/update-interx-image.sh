#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

INTERX_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_INTERX)
INTERX_INTEGRITY="${INTERX_BRANCH}_${INTERX_HASH}"

INTERX_IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/interx" "interx" "latest" "$INTERX_INTEGRITY" || echo "error")
if [ "$INTERX_IMAGE_EXISTS" == "False" ]; then
    echo "All images were updated, starting interx image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/interx" "interx" "latest" "$INTERX_INTEGRITY" "REPO=$INTERX_REPO" "BRANCH=$INTERX_BRANCH" #4
elif [ "$INTERX_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: interx image is up to date"
else
    echo "ERROR: Failed to test if interx image exists"
    exit 1
fi
