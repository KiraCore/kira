#!/bin/bash

exec 2>&1
set -e
set -x

source "/etc/profile" &>/dev/null

TOOLS_IMAGE_EXISTS=$($WORKSTATION_SCRIPTS/image-updated.sh "$KIRA_DOCKER/tools-image" "tools-image" || echo "error")
if [ "$TOOLS_IMAGE_EXISTS" == "False" ]; then
    $WORKSTATION_SCRIPTS/delete-image.sh "$KIRA_DOCKER/validator" "validator" #1

    echo "INFO: Updating tools image..."
    $WORKSTATION_SCRIPTS/update-image.sh "$KIRA_DOCKER/tools-image" "tools-image" #5
elif [ "$TOOLS_IMAGE_EXISTS" == "True" ]; then
    echo "INFO: tools-image is up to date"
else
    echo "ERROR: Failed to test if tools image exists"
    exit 1
fi
