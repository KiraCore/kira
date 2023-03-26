#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-reinitalize.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echoInfo "INFO: Re-Initalizing Infrastructure..."
echoInfo "INFO: Default infrastructure URL: $(globGet INFRA_SRC)"

NEW_INFRA_SRC=""
INFRA_SRC_OUT="/tmp/kira.zip"
SUCCESS_DOWNLOAD="false"

while [ "$SUCCESS_DOWNLOAD" == "false" ] ; do 
    echoNErr "Press [Y]es to keep default infrastructure URL or [C]hange source: " && pressToContinue y c && ACCEPT=$(toLower "$(globGet OPTION)")

    if [ "$ACCEPT" == "c" ] ; then
        read  -p "Input URL, version or CID hash of the new infrastructure source: " NEW_INFRA_SRC
        ($(isVersion "$NEW_INFRA_SRC")) && NEW_INFRA_SRC="https://github.com/KiraCore/kira/releases/download/$NEW_INFRA_SRC/kira.zip"
        ($(isCID "$NEW_INFRA_SRC")) && NEW_INFRA_SRC="https://ipfs.kira.network/ipfs/$NEW_INFRA_SRC/kira.zip"
    else
        NEW_INFRA_SRC="$(globGet INFRA_SRC)"
    fi

    echoInfo "INFO: Downloading initialization script..."
    rm -fv $INFRA_SRC_OUT
    safeWget $INFRA_SRC_OUT $NEW_INFRA_SRC "$(globGet KIRA_COSIGN_PUB)" || ( echo "ERROR: Failed to download $NEW_INFRA_SRC" && rm -fv $INIT_SRC_OUT )
    
    if [ ! -f "$INFRA_SRC_OUT" ] ; then
        echoNErr "Press [Y]es to try again or [X] to exit: " && pressToContinue y x && ACCEPT=$(toLower "$(globGet OPTION)")

        [ "$ACCEPT" == "x" ] && break
    else
        SUCCESS_DOWNLOAD="true"
        chmod 555 $INFRA_SRC_OUT
        break
    fi
done

if [ "$SUCCESS_DOWNLOAD" != "true" ] ; then
    echoInfo "INFO: Re-initialization failed or was aborted"
    echoErr "Press any key to continue or Ctrl+C to abort..." && pressToContinue
else
    rm -rfv "$KIRA_INFRA" && mkdir -p "$KIRA_INFRA"
    unzip $INFRA_SRC_OUT -d $KIRA_INFRA
    chmod -R 555 $KIRA_INFRA

    # update old processes
    rm -rfv $KIRA_MANAGER $KIRA_SETUP
    mkdir -p $KIRA_MANAGER $KIRA_SETUP
    cp -rfv "$KIRA_WORKSTATION/." $KIRA_MANAGER
    chmod -R 555 $KIRA_MANAGER

    echoInfo "INFO: ReStarting init script to launch setup menu..."
    source $KIRA_MANAGER/init.sh --infra-src="$NEW_INFRA_SRC" --init-mode="interactive"
fi
