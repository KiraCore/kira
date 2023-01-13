#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/chain-id-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NEW_BASE_IMAGE_SRC=""

echoInfo "INFO: Started base image selection!"
while : ; do
    echoInfo "INFO: Default base image: $(globGet BASE_IMAGE_SRC)"
    echoInfo "INFO: Base image should have a format of URL or release version, e.g. vX.X.X"
    echoNErr "Input name of your NEW KIRA base-image, or press [ENTER] for default: " && read NEW_BASE_IMAGE_SRC

    [ -z "$NEW_BASE_IMAGE_SRC" ] && NEW_BASE_IMAGE_SRC=$(globGet BASE_IMAGE_SRC)
    ($(isVersion "$NEW_BASE_IMAGE_SRC")) && NEW_BASE_IMAGE_SRC="ghcr.io/kiracore/docker/kira-base:$NEW_BASE_IMAGE_SRC"

    echoInfo "INFO: Veryfying base image, please wait..."
    SUCCESS="true"
    cosign verify --key "$(globGet KIRA_COSIGN_PUB)" "$NEW_BASE_IMAGE_SRC" || SUCCESS="false"

    if [ "$SUCCESS" == "false" ] ; then
        echoErr "ERROR: Failed to verify source of the '$NEW_BASE_IMAGE_SRC', image is NOT safe to use!"
        echoNErr "Choose to [F]orce unsafe image to be used or [T]ry again: " && pressToContinue f t
        [ "$(globGet OPTION)" == "t" ] && continue
    else
        echoInfo "SUCCESS: Base image is safe to use!"
        sleep 1
        break
    fi
done

globSet NEW_BASE_IMAGE_SRC "$NEW_BASE_IMAGE_SRC"
echoInfo "INFO: Finished running base image selector"