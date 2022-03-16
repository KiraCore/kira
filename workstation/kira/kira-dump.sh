#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/kira-dump.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart

SETUP_START_DT=$(globGet SETUP_START_DT)

set +x
echoWarn "--------------------------------------------------"
echoWarn "| STARTING KIRA LOGS DUMP $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|      VARS_FILE: $VARS_FILE"
echoWarn "|       NETWORKS: $NETWORKS"
echoWarn "|             ID: $ID"
echoWarn "| SETUP START DT: $SETUP_START_DT"
echoWarn "--------------------------------------------------"
set -x

CONTAINERS=$(globGet "CONTAINERS")

i=0
total=0
if (! $(isNullOrEmpty $CONTAINERS)) ; then
    echoInfo "INFO: Dumping containers logs..."
    for NAME in $CONTAINERS; do
        i=$((i + 1))
        $KIRAMGR_SCRIPTS/dump-logs.sh $NAME "false" || echoErr "ERROR: Failed to dump container $NAME logs"
        total=$((total + 1))
    done

    echoInfo "INFO: Dumped logs of ${i}/${total} containers"
else
    echoWarn "WARNING: Can NOT dump containers log, no containers were found"
fi

echoInfo "INFO: Dumping firewal info..."
ufw status verbose >"$KIRA_DUMP/ufw-status.txt" || echoErr "ERROR: Failed to dump firewal status"

echoInfo "INFO: Dumping service logs..."
journalctl --since "$PLAN_START_DT" -u kiraplan -b --no-pager --output cat > "$KIRA_DUMP/kiraplan-dump.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
journalctl --since "$SETUP_START_DT" -u kiraup -b --no-pager --output cat > "$KIRA_DUMP/kiraup-dump.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
journalctl --since "$SETUP_START_DT" -u kirascan -b --no-pager --output cat > "$KIRA_DUMP/kirascan-dump.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"

cat $(globGet UPDATE_TOOLS_LOG) > "$KIRA_DUMP/kiraup-tools-dump.log.txt" || echoErr "ERROR: Tools Update Log was NOT found!"
cat $(globGet UPDATE_CLEANUP_LOG) > "$KIRA_DUMP/kiraup-cleanup-dump.log.txt" || echoErr "ERROR: Cleanup Update Log was NOT found!"
cat $(globGet UPDATE_CONTAINERS_LOG) > "$KIRA_DUMP/kiraup-containers-dump.log.txt" || echoErr "ERROR: Containers Update Log was NOT found!"

echoInfo "INFO: Compresing all dumped files..."
ZIP_FILE="$KIRA_DUMP/kira.zip"
rm -fv $ZIP_FILE
zip -0 -r -v $ZIP_FILE $KIRA_DUMP

set +x
echoInfo "INFO: All dump files were exported to $ZIP_FILE"
echoWarn "------------------------------------------------"
echoWarn "|    FINISHED: KIRA LOGS DUMP                  |"
echoWarn "|     ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x
