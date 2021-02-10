#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-reinitalize.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

GIT_USER=$(echo $INFRA_REPO | cut -d'/' -f4) 
GIT_REPO=$(echo $INFRA_REPO | cut -d'/' -f5)
NEW_BRANCH=$INFRA_BRANCH
DEFAULT_INIT_SCRIPT="https://raw.githubusercontent.com/$GIT_USER/$GIT_REPO/$INFRA_BRANCH/workstation/init.sh"

echo "INFO: Re-Initalizing Infrastructure..."
echo "INFO: Default init script: $DEFAULT_INIT_SCRIPT"

INIT_SCRIPT_OUT="/tmp/init.sh"
SUCCESS_DOWNLOAD="false"
SUCCESS_HASH_CHECK="false"
FILE_HASH=""
INIT_SCRIPT=""
INTEGRITY_HASH=""

while [ "${SUCCESS_DOWNLOAD,,}" == "false" ] ; do 
    ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|c)$ ]] ; do echoNErr "Press [Y]es to keep default initialization script or [C]hange URL: " && read  -d'' -s -n1 ACCEPT && echo "" ; done

    if [ "${ACCEPT,,}" == "c" ] ; then
        read  -p "Input URL of the new initialization script: " INIT_SCRIPT
    else
        INIT_SCRIPT=$DEFAULT_INIT_SCRIPT
    fi 

    if [ "${INIT_SCRIPT}" == "$DEFAULT_INIT_SCRIPT" ] ; then
        echo "INFO: Default initialization script was selected"
        ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|c)$ ]] ; do echoNErr "Press [Y]es to keep default infra branch '$INFRA_BRANCH' or [C]hange it: " && read  -d'' -s -n1 ACCEPT && echo "" ; done
        
        if [ "${ACCEPT,,}" == "c" ] ; then
            read  -p "Input desired banch name of the $GIT_USER/$GIT_REPO repository: " NEW_BRANCH
            [ -z "$NEW_BRANCH" ] && NEW_BRANCH=$INFRA_BRANCH
            echo "INFO: Changing infrastructure branch from $INFRA_BRANCH to $NEW_BRANCH"
            INIT_SCRIPT="https://raw.githubusercontent.com/$GIT_USER/$GIT_REPO/$NEW_BRANCH/workstation/init.sh"
        fi
    fi
    
    echo "INFO: Downloading initialization script $INIT_SCRIPT"
    rm -fv $INIT_SCRIPT_OUT
    wget $INIT_SCRIPT -O $INIT_SCRIPT_OUT || ( echo "ERROR: Failed to download $INIT_SCRIPT" && rm -fv $INIT_SCRIPT_OUT && NEW_BRANCH=$INFRA_BRANCH )
    
    if [ ! -f "$INIT_SCRIPT_OUT" ] ; then
        ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|x)$ ]] ; do echoNErr "Press [Y]es to try again or [X] to exit: " && read  -d'' -s -n1 ACCEPT && echo "" ; done
        [ "${ACCEPT,,}" == "x" ] && break
    else
        SUCCESS_DOWNLOAD="true"
        chmod 555 $INIT_SCRIPT_OUT
        FILE_HASH=$(echo $(sha256sum $INIT_SCRIPT_OUT) | awk '{print $1;}')
        break
    fi
done

if [ "${SUCCESS_DOWNLOAD,,}" == "true" ] ; then 
    echo "INFO: Success, init script was downloaded!"
    echo "INFO: SHA256: $FILE_HASH"
    while [ "${SUCCESS_HASH_CHECK,,}" == "false" ] ; do 
        ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(v|c)$ ]] ; do echoNErr "Proceed to [V]erify checksum or [C]ontinue to downloaded script: " && read  -d'' -s -n1 ACCEPT && echo "" ; done

        if [ "${ACCEPT,,}" == "v" ] ; then
            read -p "Input sha256sum hash of the file: " INTEGRITY_HASH
        else
            echoInfo "INFO: Hash verification was skipped"
            echoWarn "WARNING: Always verify integrity of scripts, otherwise you might be executing malicious code"
            echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
            SUCCESS_HASH_CHECK="true"
            break
        fi
    
        echo "$INTEGRITY_HASH $INIT_SCRIPT_OUT" | sha256sum --check && SUCCESS_HASH_CHECK="true"
        [ "${SUCCESS_HASH_CHECK,,}" == "false" ] && echo "WARNING: File has diffrent shecksum then expected!"
        [ "${SUCCESS_HASH_CHECK,,}" == "true" ] && break
    done
fi

if [ "${SUCCESS_HASH_CHECK,,}" != "true" ] || [ "${SUCCESS_DOWNLOAD,,}" != "true" ] ; then
    echo -e "\nINFO: Re-initialization failed or was aborted\n"
    echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
else
    echo -e "\nINFO: Hash verification was sucessfull, ready to re-initalize environment\n"

    ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(r|c)$ ]] ; do echoNErr "Proceed to [R]einstall all dependencies or [C]ontinue partial reinitialization: " && read -d'' -s -n1 ACCEPT && echo ""; done
    if [ "${ACCEPT,,}" == "r" ] ; then # wipe setup lock files
        rm -fvr $KIRA_SETUP
        mkdir -p $KIRA_SETUP
    fi

    [ "$INFRA_BRANCH" != "$NEW_BRANCH" ] && CDHelper text lineswap --insert="INFRA_BRANCH=$NEW_BRANCH" --prefix="INFRA_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
    source $INIT_SCRIPT_OUT "$NEW_BRANCH"
fi

