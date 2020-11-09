#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="_${SEKAI_HASH}"

VALIDATOR_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/validator" "validator" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "$VALIDATOR_IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting validator image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/validator" "validator" "latest" "$SEKAI_INTEGRITY" "REPO=$SEKAI_REPO" "BRANCH=$SEKAI_BRANCH" #4
elif [ "$VALIDATOR_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: validator-image is up to date"
else
    echo "ERROR: Failed to test if validator image exists"
    exit 1
fi
