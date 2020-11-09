#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

EMAIL_SENT=$HOME/email_sent

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

if [ "${MAINTENANCE_MODE}" == "true"  ] || [ -f "$MAINTENANCE_FILE" ] ; then
     echo "INFO: Entering maitenance mode!"
     exit 0
fi

# cleanup large files
find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} +
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +

if [ -f "$INIT_END_FILE" ] ; then
   echo "INFO: Initialization was successfull"
else
   echo "INFO: Pending initialization"
   exit 0
fi

RPC_STATUS="$(curl 127.0.0.1:$RPC_PROXY_PORT/status 2>/dev/null)" || RPC_STATUS="{}"
RPC_CATCHING_UP="$(echo $RPC_STATUS | jq -r '.result.sync_info.catching_up')" || RPC_CATCHING_UP="true"

set +e
STATUS_NGINX="$(systemctl2 is-active nginx.service)"
STATUS_SEKAI="$(systemctl2 is-active sekaid.service)"
#STATUS_LCD="$(systemctl2 is-active lcd.service)"
STATUS_FAUCET="$(systemctl2 is-active faucet.service)"
set -e

[ -z "$STATUS_NGINX" ] && STATUS_NGINX="unknown"
[ -z "$STATUS_SEKAI" ] && STATUS_SEKAI="unknown"
#[ -z "$STATUS_LCD" ] && STATUS_LCD="unknown"
[ -z "$STATUS_FAUCET" ] && STATUS_FAUCET="unknown"

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height.txt" && touch $BLOCK_HEIGHT_FILE
HEIGHT=$(sekaid status 2>/dev/null | jq -r '.sync_info.latest_block_height' 2>/dev/null | xargs || echo "")
PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)

if [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ; then # not a number
    HEIGHT=0
fi

echo "$HEIGHT" > $BLOCK_HEIGHT_FILE

if [ -z "$PREVIOUS_HEIGHT" ] || [ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ] ; then # not a number
    PREVIOUS_HEIGHT=0
fi

BLOCK_CHANGED="True"
if [ $PREVIOUS_HEIGHT -ge $HEIGHT  ] ; then
    echo "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
    BLOCK_CHANGED="False"
else
    echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"

#  [ "${STATUS_FAUCET}" != "active" ]
if [ "$BLOCK_CHANGED" == "False" ] || [ "${STATUS_SEKAI}" != "active" ] || [ "${STATUS_NGINX}" != "active" ] ; then
    echo "ERROR: One of the services is NOT active: Sekai($STATUS_SEKAI), Faucet($STATUS_FAUCET) or NGINX($STATUS_NGINX)"

    if [ "${STATUS_SEKAI}" != "active" ] ; then
        echo ">> Sekai log:"
        tail -n 100 /var/log/journal/sekaid.service.log || True

        #systemctl2 stop lcd || echo "ERROR: Failed to stop lcd service"
        systemctl2 stop nginx || echo "ERROR: Failed to stop nginx service"
        systemctl2 stop sekaid || echo "ERROR: Failed to stop sekaid service"

        kill $(ps aux | grep '[n]ginx' | awk '{print $2}') || echo "ERROR: Failed to kill nginx"
        kill $(ps aux | grep '[s]ekaid' | awk '{print $2}') || echo "ERROR: Failed to kill sekaid"

        systemctl2 start sekaid || systemctl2 status sekaid.service || echo "ERROR: Failed to re-start sekaid service" || true
    fi

    ##if [ "${STATUS_LCD}" != "active" ] || [ "${STATUS_SEKAI}" != "active" ] ; then
    ##    echo ">> LCD log:"
    ##    tail -n 100 /var/log/journal/lcd.service.log || true
##
    ##    systemctl2 stop lcd || echo "ERROR: Failed to stop lcd service"
    ##    systemctl2 stop nginx || echo "ERROR: Failed to stop nginx service"
##
    ##    kill $(ps aux | grep '[s]ekaid' | awk '{print $2}') || echo "ERROR: Failed to kill sekaid"
    ##    kill $(ps aux | grep '[n]ginx' | awk '{print $2}') || echo "ERROR: Failed to kill nginx"
##
    ##    systemctl2 start lcd || systemctl2 status lcd.service || echo "ERROR: Failed to re-start lcd service" || true
    ##fi

    if [ "${STATUS_NGINX}" != "active" ] || [ "${STATUS_SEKAI}" != "active" ] ; then
        echo ">> NGINX log:"
        tail -n 100 /var/log/journal/nginx.service.log || true
        nginx -t || echo "ERROR: Failed to check nginx config"
        systemctl2 stop nginx || echo "ERROR: Failed to stop nginx service"
        kill $(ps aux | grep '[n]ginx' | awk '{print $2}') || echo "ERROR: Failed to kill nginx"
        systemctl2 start nginx || systemctl2 status nginx.service || echo "ERROR: Failed to re-start nginx service" || true
    fi

    #if [ "${STATUS_FAUCET}" != "active" ]  ; then
    #    echo ">> Faucet log:"
    #    tail -n 100 /var/log/journal/faucet.nginx.log || true
    #    systemctl2 restart faucet || systemctl2 status faucet.service || echo "Failed to re-start faucet service" || true
    #fi

    if [ -f "$EMAIL_SENT" ] ; then
        echo "Notification Email was already sent."
    else
        BODY="Issue Raport [$(date)]
   Sekai Status: $STATUS_SEKAI
  Faucet Status: $STATUS_FAUCET
   NGINX Status: $STATUS_NGINX
  LATEST HEIGHT: $HEIGHT
PREVIOUS HEIGHT: $PREVIOUS_HEIGHT

Attached $(find $SELF_LOGS -type f | wc -l) Log Files
   RPC Status: $RPC_STATUS"
        echo "Sending Healthcheck Notification Email..."
        touch $EMAIL_SENT
        if [ "$NOTIFICATIONS" == "True" ] ; then
        CDHelper email send \
         --to="$EMAIL_NOTIFY" \
         --subject="[$MONIKER] Healthcheck Raised" \
         --body="$BODY" \
         --html="false" \
         --recursive="true" \
         --attachments="$SELF_LOGS,$JOURNAL_LOGS"
        fi
        sleep 120 # allow user to grab log output
        rm -f ${SELF_LOGS}/healthcheck_script_output.txt # remove old log to save space
    fi
    exit 1  
else 
    echo "SUCCESS: All services are up and running!"
    if [ -f "$EMAIL_SENT" ] ; then
        echo "INFO: Sending confirmation email, that service recovered!"
        rm -f $EMAIL_SENT # if email was sent then remove and send new one
        if [ "$NOTIFICATIONS" == "True" ] ; then 
        CDHelper email send \
         --to="$EMAIL_NOTIFY" \
         --subject="[$MONIKER] Healthcheck Rerovered" \
         --body="[$(date)] Sekai($STATUS_SEKAI), Faucet($STATUS_FAUCET) and NGINX($STATUS_NGINX) suceeded. RPC Status => $RPC_STATUS" \
         --html="false" || true
        fi
    fi
    sleep 120 # allow user to grab log output
    rm -f $SELF_LOGS/healthcheck_script_output.txt # remove old log to save space
fi

echo "INFO: Healthcheck => STOP"