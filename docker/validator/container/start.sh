#!/bin/bash

exec 2>&1
set -e
set -x

#echo "Container STARTED"
#
#[ -z "$UPDATE_REPO" ] && UPDATE_REPO="https://github.com/KiraCore/GoZ"
#[ -z "$UPDATE_BRANCH" ] && UPDATE_BRANCH="master"
#[ -z "$UPDATE_CHECKOUT" ] && UPDATE_CHECKOUT=""
#
#echo "Updating automated execution repo..."
#rm -r -f $SELF_UPDATE_TMP
#${SELF_SCRIPTS}/git-pull.sh "${UPDATE_REPO}" "${UPDATE_BRANCH}" "${UPDATE_CHECKOUT}" "${SELF_UPDATE_TMP}"
#rsync -ra $SELF_UPDATE_TMP/* $SELF_UPDATE
#chmod -R 777 $SELF_UPDATE

# Rate Limit
sleep 5

while [ "${MAINTENANCE_MODE}" == "true"  ] || [ -f "$MAINTENANCE_FILE" ] ; do echo "[$(date '+%d/%m/%Y %H:%M:%S')] WARNING: Maitenance..." ; sleep 60 ; done

if [ -f "$INIT_END_FILE" ] ; then
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] SUCCESS: on_success() => START" && touch $SUCCESS_START_FILE
   $ON_SUCCESS_SCRIPT $> $SELF_LOGS/success_script_output.txt
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] SUCCESS: on_success() => END" && touch $SUCCESS_END_FILE
   while : ; do echo "[$(date '+%d/%m/%Y %H:%M:%S')] SUCCESS: Running..." ; sleep 3600 ; done
   exit 0
elif [ -f "$INIT_START_FILE" ] ; then
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] ERROR: on_failure() => START" && touch $FAILURE_START_FILE
   $ON_FAILURE_SCRIPT $> $SELF_LOGS/failure_script_output.txt
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] ERROR: on_failure() => STOP" && touch $FAILURE_END_FILE
   while : ; do echo "[$(date '+%d/%m/%Y %H:%M:%S')] FAILURE: Halted..." ; sleep 3600 ; done
   exit 1
else
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] INFO: on_init() => START" && touch $INIT_START_FILE
   $ON_INIT_SCRIPT $> $SELF_LOGS/init_script_output.txt
   echo "[$(date '+%d/%m/%Y %H:%M:%S')] INFO: on_init() => STOP" && touch $INIT_END_FILE
fi
