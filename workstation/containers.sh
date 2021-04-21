#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/images.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SRIPT_START_TIME="$(date -u +%s)"
cd $HOME

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: CONTAINERS BUILD SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "|    INFRA MODE: $INFRA_MODE"
echoWarn "| EXTERNAL SYNC: $EXTERNAL_SYNC"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Starting containers build..."

if [ "${INFRA_MODE,,}" == "local" ] ; then
    $KIRA_MANAGER/containers/start-validator.sh 
    $KIRA_MANAGER/containers/start-sentry.sh 
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    if (! $(isFileEmpty $PUBLIC_SEEDS )) || (! $(isFileEmpty $PUBLIC_PEERS )) ; then
        # save snapshot from sentry first
        $KIRA_MANAGER/containers/start-sentry.sh "true"
        $KIRA_MANAGER/containers/start-priv-sentry.sh
    elif (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
        # save snapshot from private sentry first
        $KIRA_MANAGER/containers/start-priv-sentry.sh "true"
        $KIRA_MANAGER/containers/start-sentry.sh
    else
        echoWarn "WARNING: No public or priveate seeds were found, syning your node from external source will not be possible"
        exit 1
    fi

    $KIRA_MANAGER/containers/start-seed.sh
    $KIRA_MANAGER/containers/start-interx.sh 
    $KIRA_MANAGER/containers/start-frontend.sh 
elif [ "${INFRA_MODE,,}" == "validator" ] ; then
    if [ "${EXTERNAL_SYNC,,}" == "false" ] ; then
        $KIRA_MANAGER/containers/start-validator.sh 
        $KIRA_MANAGER/containers/start-sentry.sh 
        $KIRA_MANAGER/containers/start-priv-sentry.sh 
        $KIRA_MANAGER/containers/start-interx.sh
    else 
        if (! $(isFileEmpty $PUBLIC_SEEDS )) || (! $(isFileEmpty $PUBLIC_PEERS )) ; then
            # save snapshot from sentry first
            $KIRA_MANAGER/containers/start-sentry.sh "true"
            $KIRA_MANAGER/containers/start-priv-sentry.sh
        elif (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
            # save snapshot from private sentry first
            $KIRA_MANAGER/containers/start-priv-sentry.sh "true"
            $KIRA_MANAGER/containers/start-sentry.sh
        else
            echoWarn "WARNING: No public or priveate seeds were found, syning your node from external source will not be possible"
            exit 1
        fi
        $KIRA_MANAGER/containers/start-interx.sh
        $KIRA_MANAGER/containers/start-validator.sh 
    fi
else
  echoErr "ERROR: Unrecognized infra mode ${INFRA_MODE}"
  exit 1
fi

echoInfo "INFO: Containers build was finalized.."

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS BUILD SCRIPT            |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x