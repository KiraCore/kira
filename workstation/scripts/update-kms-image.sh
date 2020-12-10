#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

KMS_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_KMS)
KMS_INTEGRITY="${KMS_BRANCH}_${KMS_HASH}"

KMS_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/kms" "kms" "latest" "$KMS_INTEGRITY" || echo "error")
if [ "$KMS_IMAGE_EXISTS" == "False" ]; then
    echo "All imags were updated, starting kms image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/kms" "kms" "latest" "$KMS_INTEGRITY" "REPO=$KMS_REPO" "BRANCH=$KMS_BRANCH" #4
elif [ "$KMS_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: kms image is up to date"
else
    echo "ERROR: Failed to test if kms image exists"
    exit 1
fi
