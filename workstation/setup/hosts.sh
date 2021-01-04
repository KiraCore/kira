
#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

# HASH_CHECK=$(echo "
# " | md5sum | awk '{print $1}') 
# 
# SETUP_CHECK="$KIRA_SETUP/hosts-v0.0.8-$HASH_CHECK" 
# if [ ! -f "$SETUP_CHECK" ] ; then
#     echo "INFO: Setting up default hosts..."
#     systemctl restart docker || echo "WARNING: Failed to restart docker"
#     touch $SETUP_CHECK
# else
#     echo "INFO: Default host names were already defined"
# fi
