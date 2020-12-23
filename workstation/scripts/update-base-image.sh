#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

BASE_IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/base-image" "base-image" || echo "error")
if [ "$BASE_IMAGE_EXISTS" == "False" ]; then
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/frontend" "frontend"
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/interx" "interx"
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/sentry" "sentry"
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/validator" "validator"

    echo "INFO: Updating base image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/base-image" "base-image" "latest"
elif [ "$BASE_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: base-image is up to date"
else
    echo "ERROR: Failed to test if base image exists"
    exit 1
fi
