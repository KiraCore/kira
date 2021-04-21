#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/cleanup.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
cd $HOME

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CLEANUP SCRIPT                       |"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Restarting docker..."
systemctl daemon-reload  || echoErr "ERROR: Failed to reload systemctl daemon"
systemctl restart docker || ( echoErr "ERROR: Failed to restart docker service" && exit 1 )

sleep 3

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    $KIRA_SCRIPTS/container-delete.sh "$name"
done

echoInfo "INFO: KIRA Scan service cleanup..."
rm -frv "$SCAN_DIR" && mkdir -p "$SCAN_DIR"

systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )

echoInfo "INFO: Docker common directories cleanup..."
rm -fv $TMP_GENESIS_PATH
[ "${NEW_NETWORK,,}" == "false" ] && cp -afv $LOCAL_GENESIS_PATH $TMP_GENESIS_PATH
rm -rfv "$DOCKER_COMMON" "$DOCKER_COMMON_RO" && mkdir -p "$DOCKER_COMMON" "$DOCKER_COMMON_RO" && rm -fv $LOCAL_GENESIS_PATH
[ "${NEW_NETWORK,,}" == "false" ] && cp -afv $TMP_GENESIS_PATH $LOCAL_GENESIS_PATH

echoInfo "INFO: Restarting firewall settings..."
$KIRA_MANAGER/networking.sh

echoInfo "INFO: Loading secrets & generating mnemonics..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

$KIRAMGR_SCRIPTS/restart-networks.sh "false" # restarts all network without re-connecting containers

echoInfo "INFO: Updating IP addresses info..."
systemctl restart kirascan || ( echoErr "ERROR: Failed to restart kirascan service" && exit 1 )
rm -fv "$DOCKER_COMMON_RO/public_ip" "$DOCKER_COMMON_RO/local_ip"
i=0 && LOCAL_IP="" && PUBLIC_IP=""
while ( (! $(isIp "$LOCAL_IP")) && (! $(isPublicIp "$PUBLIC_IP")) ) ; do
    i=$((i + 1))
    PUBLIC_IP=$(cat "$DOCKER_COMMON_RO/public_ip" || echo -n "")
    LOCAL_IP=$(cat "$DOCKER_COMMON_RO/local_ip" || echo -n "")
    [ "$i" == "30" ] && echoErr "ERROR: Public IPv4 ($PUBLIC_IP) or Local IPv4 ($LOCAL_IP) address could not be found. Setup CAN NOT continue!" && exit 1 
    echoInfo "INFO: Waiting for public and local IPv4 address to be updated..."
    sleep 30
done

echoInfo "INFO: Setting up snapshots and geesis file..."
DOCKER_SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.zip"
rm -rfv $DOCKER_SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    ln -fv "$KIRA_SNAP_PATH" "$DOCKER_SNAP_DESTINATION"
else
    echoWarn "WARNING: Snapshot file '$KIRA_SNAP_PATH' was NOT found, slow sync will be performed!"
fi

echoInfo "INFO: Setting up essential environment variables..."
if [ "${INFRA_MODE,,}" == "local" ] ; then
    EXTERNAL_SYNC="false"
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    EXTERNAL_SYNC="true"
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    if [ "${NEW_NETWORK,,}" == "true" ] || ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) && ($(isFileEmpty $PRIVATE_SEEDS )) && ($(isFileEmpty $PRIVATE_PEERS )) ) ; then
        EXTERNAL_SYNC="false" 
    else
        EXTERNAL_SYNC="true"
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

[ "${EXTERNAL_SYNC,,}" == "false" ] && echoInfo "INFO: Nodes will be synced from the pre-generated genesis in the '$INFRA_MODE' mode"
[ "${EXTERNAL_SYNC,,}" == "true" ] && echoInfo "INFO: Nodes will be synced from the external seed node in the '$INFRA_MODE' mode"
CDHelper text lineswap --insert="EXTERNAL_SYNC=$EXTERNAL_SYNC" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True

if [ "${NEW_NETWORK,,}" != "true" ] ; then 
    echoInfo "INFO: Attempting to access genesis file from local configuration..."
    [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Failed to locate genesis file, external sync is not possible" && exit 1
else
    [ -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was present before network was instantiated!" && exit 1
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CLEANUP SCRIPT                      |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x