#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/scripts/update-kira-image.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

SEKAI_HASH=$($KIRA_SCRIPTS/git-hash.sh $KIRA_SEKAI)
SEKAI_INTEGRITY="${SEKAI_BRANCH}_${SEKAI_HASH}"

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/kira" "kira" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "${IMAGE_EXISTS,,}" == "false" ]; then
    echoInfo "INFO: All imags were updated, starting kira image..."
    $KIRAMGR_SCRIPTS/update-image.sh "$KIRA_DOCKER/kira" "kira" "latest" "$SEKAI_INTEGRITY" "REPO=$SEKAI_REPO" "BRANCH=$SEKAI_BRANCH" #4
elif [ "${IMAGE_EXISTS,,}" == "true" ]; then
    echoInfo "INFO: kira-image is up to date"
else
    echoErr "ERROR: Failed to test if kira image exists or not: '$IMAGE_EXISTS'"
    exit 1
fi

IMAGE_EXISTS=$($KIRAMGR_SCRIPTS/image-updated.sh "$KIRA_DOCKER/kira" "kira" "latest" "$SEKAI_INTEGRITY" || echo "error")
if [ "${IMAGE_EXISTS,,}" != "true" ] ; then
    echoErr "ERROR: Failed to create kira image ($IMAGE_EXISTS)"
    exit 1
fi