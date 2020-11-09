#!/bin/bash
exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_WORKSTATION/image-updated.sh) && nano $KIRA_WORKSTATION/image-updated.sh && chmod 777 $KIRA_WORKSTATION/image-updated.sh
# Use Example:
# $KIRA_WORKSTATION/image-updated.sh "$KIRA_INFRA/docker/base-image" "base-image" "latest"

source "/etc/profile" &> /dev/null

IMAGE_DIR=$1
IMAGE_NAME=$2
IMAGE_TAG=$3
INTEGRITY=$4

[ -z "$IMAGE_TAG" ] && IMAGE_TAG="latest"

KIRA_SETUP_FILE="$KIRA_SETUP/$IMAGE_NAME-$IMAGE_TAG"

# make sure setup file exists
touch $KIRA_SETUP_FILE

cd $IMAGE_DIR

OLD_HASH=$(cat $KIRA_SETUP_FILE)
NEW_HASH="$(hashdeep -r -l . | sort | md5sum | awk '{print $1}')-$INTEGRITY"

CREATE_NEW_IMAGE="False"
if [ -z $(docker images -q $IMAGE_NAME || "") ] || [ "$OLD_HASH" != "$NEW_HASH" ] ; then
    echo "False"
else
    echo "True"
fi