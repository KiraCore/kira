#!/bin/bash
exec 2>&1
set +e && source "/etc/profile" &>/dev/null && set -e

IMAGE_DIR=$1
IMAGE_NAME=$2
IMAGE_TAG=$3
INTEGRITY=$4

[ -z "$IMAGE_TAG" ] && IMAGE_TAG="latest"

KIRA_SETUP_FILE="$KIRA_SETUP/$IMAGE_NAME-$IMAGE_TAG"

# make sure setup file exists
touch $KIRA_SETUP_FILE

cd $IMAGE_DIR

OLD_HASH=$(tryCat $KIRA_SETUP_FILE)
NEW_HASH=$(CDHelper hash SHA256 -p="$IMAGE_DIR" -x=true -r=true --silent=true || echo "")

if [ -z "$NEW_HASH" ] ; then
    echo "false"
else
    NEW_HASH="$NEW_HASH-$INTEGRITY"

    if ! command -v docker images -q $IMAGE_NAME &> /dev/null ; then
        echo "false"
    elif [ -z $(docker images -q $IMAGE_NAME || "") ] || [ "$OLD_HASH" != "$NEW_HASH" ] ; then
        echo "false"
    else
        echo "true"
    fi
fi