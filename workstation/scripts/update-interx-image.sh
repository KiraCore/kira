#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/update--interx-image.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

INTERX_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_INTERX)
INTERX_INTEGRITY="${INTERX_BRANCH}_${INTERX_HASH}"

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/interx" "interx" "latest" "$INTERX_INTEGRITY" || echo "error")
if [ "${IMAGE_EXISTS,,}" == "false" ]; then
    echoInfo "INFO: All images were updated, starting interx image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/interx" "interx" "latest" "$INTERX_INTEGRITY" "REPO=$INTERX_REPO" "BRANCH=$INTERX_BRANCH" #4
elif [ "${IMAGE_EXISTS,,}" == "frue" ]; then
    echoInfo "INFO: interx image is up to date"
else
    echoErr "ERROR: Failed to test if interx image exists: '$IMAGE_EXISTS'"
    exit 1
fi
