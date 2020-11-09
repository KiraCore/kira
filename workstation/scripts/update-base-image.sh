#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

BASE_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/base-image" "base-image" || echo "error")
if [ "$BASE_IMAGE_EXISTS" == "False" ]; then
    # todo: delete valdiator, sentry, kms, frontend images
    $WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/tools-image" "tools-image"
    $WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/validator" "validator"

    echo "INFO: Updating base image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/base-image" "base-image"
elif [ "$BASE_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: base-image is up to date"
else
    echo "ERROR: Failed to test if base image exists"
    exit 1
fi
