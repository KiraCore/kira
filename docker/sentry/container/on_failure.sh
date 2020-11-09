#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

touch $MAINTENANCE_FILE # notify entire environment to halt

#systemctl2 stop faucet || systemctl2 status faucet || true
systemctl2 stop sekaid || systemctl2 status sekaid || true
#systemctl2 stop lcd || systemctl2 status lcd || true
systemctl2 stop nginx || systemctl2 status nginx || true

if [ "$NOTIFICATIONS" == "True" ] ; then 
CDHelper email send \
 --to="$EMAIL_NOTIFY" \
 --subject="[$MONIKER] Failed to Initalize" \
 --body="[$(date)] Attached $(find $SELF_LOGS -type f | wc -l) Log Files" \
 --html="false" \
 --recursive="true" \
 --attachments="$SELF_LOGS,$JOURNAL_LOGS"
fi
