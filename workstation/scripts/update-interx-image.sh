#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="_${SEKAI_HASH}"

INTERX_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/interx" "interx" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "$INTERX_IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting interx image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/interx" "interx" "latest" "$SEKAI_INTEGRITY" "REPO=$SEKAI_REPO" "BRANCH=KIP_31" #4
elif [ "$INTERX_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: interx image is up to date"
else
    echo "ERROR: Failed to test if interx image exists"
    exit 1
fi
