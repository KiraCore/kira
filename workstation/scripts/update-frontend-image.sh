#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/update-frontend-image.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

FRONTEND_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_FRONTEND)
FRONTEND_INTEGRITY="${FRONTEND_BRANCH}_${FRONTEND_HASH}"

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$FRONTEND_INTEGRITY" || echo "error")
if [ "${IMAGE_EXISTS,,}" == "false" ]; then
    echoInfo "INFO: All imags were updated, starting frontend image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/frontend" "frontend" "latest" "$FRONTEND_INTEGRITY" "REPO=$FRONTEND_REPO" "BRANCH=$FRONTEND_BRANCH" #4
elif [ "${IMAGE_EXISTS,,}" == "true" ]; then
    echoInfo "INFO: frontend image is up to date"
else
    echoErr "ERROR: Failed to test if frontend image exists: '$IMAGE_EXISTS'"
    exit 1
fi
