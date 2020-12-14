#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_WORKSTATION/kira/kira-reinitalize.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

DEFAULT_INIT_SCRIPT="https://raw.githubusercontent.com/KiraCore/kira/KIP_51/workstation/init.sh"
echo "INFO: Re-Initalizing Infrastructure..."
echo "INFO: Default init script: $DEFAULT_INIT_SCRIPT"
        
INIT_SCRIPT_OUT="/tmp/init.sh"
SUCCESS_DOWNLOAD="false"
SUCCESS_HASH_CHECK="false"
FILE_HASH=""
INIT_SCRIPT=""

while [ "${SUCCESS_DOWNLOAD,,}" == "false" ] ; do 
    echo -en "\e[33;1mDo you want to change the default initalization script?\e[0m\c" 
    ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[33;1mPress [Y]es to confirm change URL or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done

    if [ "${ACCEPT,,}" == "y" ] ; then
        read  -p "Input URL of the new initialization script: " INIT_SCRIPT
    else
        INIT_SCRIPT=$DEFAULT_INIT_SCRIPT
    fi
    
    echo "INFO: Downloading initialization script $INIT_SCRIPT"
    rm -fv $INIT_SCRIPT_OUT || echo "INFO: Failed to remove existing script"
    wget $INIT_SCRIPT -O $INIT_SCRIPT_OUT || echo "ERROR: Failed to download $INIT_SCRIPT"
    
    if [ ! -f "$INIT_SCRIPT_OUT" ] ; then
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "x" ] ; do echo -en "\e[33;1mPress [Y]es to try again or [X] to exit: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
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
        echo -en "\e[33;1mDo you want to verify integrity hash of the downloaded script?\e[0m\c" 
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[33;1mPress [Y]es to confirm or [N]o to continue: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
        
        INTEGRITY_HASH=""
        if [ "${ACCEPT,,}" == "y" ] ; then
            read -p "Input sha256sum hash of the file: " -s INTEGRITY_HASH
        else
            echo "INFO: Hash verification was skipped"
            echo "WARNING: You should always verify integrity of scripts you run otherwise you might be executing malicious code"
            read -p "Press any key to continue or [Ctrl+C] to abort..." -n 1
            break
        fi
    
        echo "$INTEGRITY_HASH $INIT_SCRIPT_OUT" | sha256sum --check && ( SUCCESS_HASH_CHECK="true" && break )
        [ "${SUCCESS_HASH_CHECK,,}" == "false" ] && echo "WARNING: File has diffrent shecksum then expected!"
    done
fi

if [ "${SUCCESS_HASH_CHECK,,}" != "true" ] || [ "${SUCCESS_DOWNLOAD,,}" != "true" ] ; then
    echo "INFO: Re-initalization failed or was aborted"
    read -p "Press any key to continue..." -n 1
else
    echo "INFO: Hash verification was sucessfull, ready to re-initalize environment"
    read -p "Press any key to continue..." -n 1
    source $INIT_SCRIPT_OUT
fi

