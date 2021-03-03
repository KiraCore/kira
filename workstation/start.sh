#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

SKIP_UPDATE=$1
START_TIME_LAUNCH="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
PUBLIC_SEEDS="$KIRA_CONFIGS/public_seeds"
PRIVATE_SEEDS="$KIRA_CONFIGS/private_seeds"

cd $HOME

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: LAUNCH SCRIPT                       |"
echoWarn "|-----------------------------------------------"
echoWarn "|  SKIP UPDATE: $SKIP_UPDATE"
echoWarn "| SEKAI BRANCH: $SEKAI_BRANCH"
echoWarn "------------------------------------------------"
set -x

[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echoInfo "INFO: Updating kira repository and fetching changes..."
if [ "${SKIP_UPDATE,,}" == "false" ]; then
    $KIRA_MANAGER/setup.sh "$SKIP_UPDATE"
    $KIRA_MANAGER/networking.sh
    source $KIRA_MANAGER/start.sh "True"
    exit 0
fi

set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echoInfo "INFO: Restarting registry..."
$KIRA_SCRIPTS/container-restart.sh "registry" &

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    $KIRA_SCRIPTS/container-delete.sh "$name"
done

wait

echoInfo "INFO: Building images..."

rm -frv "$SCAN_DIR"
mkdir -p "$SCAN_DIR"

set -e

$KIRAMGR_SCRIPTS/update-base-image.sh
$KIRAMGR_SCRIPTS/update-kira-image.sh & 
$KIRAMGR_SCRIPTS/update-interx-image.sh &
$KIRAMGR_SCRIPTS/update-frontend-image.sh &

wait

echoInfo "INFO: All images were updated, setting up configuration files & variables..."

cp -afv "$LOCAL_GENESIS_PATH" "/tmp/genesis.json"
rm -rfv "$DOCKER_COMMON" "$DOCKER_COMMON_RO" && mkdir -p "$DOCKER_COMMON" "$DOCKER_COMMON_RO"
[ "${NEW_NETWORK,,}" == "true" ] && rm -fv "$LOCAL_GENESIS_PATH" || cp -afv  "/tmp/genesis.json" "$LOCAL_GENESIS_PATH"

if [ ! -f "$KIRA_SETUP/reboot" ] ; then
    set +x
    echoWarn "WARNING: To apply all changes your machine must be rebooted!"
    echoWarn "WARNING: After restart is compleated type 'kira' in your console terminal to continue"
    echoNErr "Press any key to initiate reboot" && read -n 1 -s && echo ""
    echoInfo "INFO: Rebooting will occur in 3 seconds and you will be logged out of your machine..."
    sleep 3
    set -x
    touch "$KIRA_SETUP/reboot"
    reboot
else
    echoInfo "INFO: Reboot was already performed, setup will continue..."
    touch "$KIRA_SETUP/rebooted"
fi

echoInfo "INFO: Loading secrets & generating mnemonics..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

$KIRAMGR_SCRIPTS/restart-networks.sh "false" # restarts all network without re-connecting containers

echoInfo "INFO: Updating IP addresses info..."

PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 2>/dev/null | awk -F'"' '{ print $2}')
LOCAL_IP=$(/sbin/ifconfig $IFACE 2>/dev/null | grep -i mask 2>/dev/null | awk '{print $2}' 2>/dev/null | cut -f2 2>/dev/null || echo "0.0.0.0")
($(isDnsOrIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" > "$DOCKER_COMMON_RO/public_ip"
($(isDnsOrIp "$LOCAL_IP")) && echo "$LOCAL_IP" > "$DOCKER_COMMON_RO/local_ip"

echoInfo "INFO: Setting up snapshots and geesis file..."

SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.zip"
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    cp -a -v -f $KIRA_SNAP_PATH "$SNAP_DESTINATION"
fi

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echoInfo "INFO: Nodes will be synced from the pre-generated genesis"
    EXTERNAL_SYNC="false"
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    echoInfo "INFO: Nodes will be synced from the external seed node"
    EXTERNAL_SYNC="true"
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    if [[ -z $(grep '[^[:space:]]' $PRIVATE_SEEDS) ]] ; then
        echoInfo "INFO: Nodes will be synced from the external seed node"
        EXTERNAL_SYNC="true"
    else
        echoInfo "INFO: Nodes will be synced from the pre-generated genesis"
        EXTERNAL_SYNC="false"
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

CDHelper text lineswap --insert="EXTERNAL_SYNC=$EXTERNAL_SYNC" --prefix="EXTERNAL_SYNC=" --path=$ETC_PROFILE --append-if-found-not=True

if [ "${NEW_NETWORK,,}" != "true" ] ; then 
    echoInfo "INFO: Attempting to access genesis file from local configuration..."
    [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Failed to locate genesis file, external sync is not possible" && exit 1
else
    [ -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was present before network was instantiated!" && exit 1
fi

echoInfo "INFO: Starting '${INFRA_MODE,,} mode' setup, external sync '$EXTERNAL_SYNC' ..."
if [ "${INFRA_MODE,,}" == "local" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh 
    $KIRA_MANAGER/containers/start-sentry.sh 
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    $KIRA_MANAGER/containers/start-sentry.sh
    $KIRA_MANAGER/containers/start-priv-sentry.sh 
    $KIRA_MANAGER/containers/start-seed.sh
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    if [ "${NEW_NETWORK,,}" == "true" ] ; then
        $KIRA_MANAGER/containers/start-validator.sh 
        $KIRA_MANAGER/containers/start-sentry.sh 
        $KIRA_MANAGER/containers/start-priv-sentry.sh 
        $KIRA_MANAGER/containers/start-interx.sh 
        $KIRA_MANAGER/containers/start-frontend.sh
    else
        $KIRA_MANAGER/containers/start-sentry.sh

        #echoInfo "INFO: No private seeds were configured, using public sentry as private seed"
        #SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry.sentrynet:$KIRA_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
        #echo "$SENTRY_SEED" > $PRIVATE_SEEDS
        #$KIRA_MANAGER/containers/start-priv-sentry.sh 

        $KIRA_MANAGER/containers/start-interx.sh 
        $KIRA_MANAGER/containers/start-frontend.sh
        $KIRA_MANAGER/containers/start-validator.sh 
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

echoInfo "INFO: Starting clenup..."
rm -fv $SNAP_DESTINATION

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: LAUNCH SCRIPT                      |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
echoWarn "------------------------------------------------"
set -x