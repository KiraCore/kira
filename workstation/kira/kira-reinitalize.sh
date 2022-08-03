#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-reinitalize.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echoInfo "INFO: Re-Initalizing Infrastructure..."
echoInfo "INFO: Default infrastructure URL: $INFRA_SRC"

INIT_SRC_OUT="/tmp/init.sh"
SUCCESS_DOWNLOAD="false"
INIT_SRC=""

while [ "${SUCCESS_DOWNLOAD,,}" == "false" ] ; do 
    ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|c)$ ]] ; do echoNErr "Press [Y]es to keep default infrastructure URL or [C]hange source: " && read  -d'' -s -n1 ACCEPT && echo "" ; done

    if [ "${ACCEPT,,}" == "c" ] ; then
        read  -p "Input URL of the new infra source: " INIT_SRC
    else
        INIT_SRC=$INFRA_SRC
    fi 

    echoInfo "INFO: Downloading initialization script..."
    rm -fv $INIT_SRC_OUT
    safeWget $INIT_SRC_OUT $INIT_SRC/init.sh || ( echo "ERROR: Failed to download $INIT_SRC/init.sh" && rm -fv $INIT_SRC_OUT )
    
    if [ ! -f "$INIT_SRC_OUT" ] ; then
        ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|x)$ ]] ; do echoNErr "Press [Y]es to try again or [X] to exit: " && read  -d'' -s -n1 ACCEPT && echo "" ; done
        [ "${ACCEPT,,}" == "x" ] && break
    else
        SUCCESS_DOWNLOAD="true"
        chmod 555 $INIT_SRC_OUT
        break
    fi
done


if [ "${SUCCESS_DOWNLOAD,,}" != "true" ] ; then
    echoInfo "INFO: Re-initialization failed or was aborted"
    echoErr "Press any key to continue or Ctrl+C to abort..." && pressToContinue
else
    echoInfo "INFO: Hash verification was sucessfull, ready to re-initalize environment"
    ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(r|c)$ ]] ; do echoNErr "Proceed to [R]einstall all dependencies or [C]ontinue partial reinitialization: " && read -d'' -s -n1 ACCEPT && echo ""; done
    if [ "${ACCEPT,,}" == "r" ] ; then # wipe setup lock files
        rm -fvr $KIRA_SETUP
        mkdir -p $KIRA_SETUP
    fi
    
    source $INIT_SRC_OUT "$INIT_SRC"
fi
