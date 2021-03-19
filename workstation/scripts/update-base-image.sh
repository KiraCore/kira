#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/base-image" "base-image" || echo "error")
if [ "${IMAGE_EXISTS,,}" == "false" ]; then
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/frontend" "frontend"
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/interx" "interx"
    $KIRAMGR_SCRIPTS/delete-image.sh "$KIRA_DOCKER/kira" "kira"

    echo "INFO: Updating base image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/base-image" "base-image" "latest"
elif [ "${IMAGE_EXISTS,,}" == "true" ]; then
    echo "INFO: base-image is up to date"
else
    echo "ERROR: Failed to test if base image exists: '$IMAGE_EXISTS'"
    exit 1
fi
