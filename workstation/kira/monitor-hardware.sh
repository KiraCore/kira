#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-hardware.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat "$KIRA_SCAN/hardware.log"
set -x

# Largest File Discovery: find / -type f -printf '%s %p\n' | sort -nr | head -10

IFACE=$(globGet IFACE)

timerStart

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA HARDWARE SCAN            |"
echoWarn "|-----------------------------------------------"
set -x

echoInfo "INFO: Discovering & Saving CPU load info..."
CPU_LOAD=$(mpstat -o JSON -u 4 1 | jsonQuickParse "idle" | awk '{print 100 - $1"%"}' || echo -e "")
globSet "CPU_UTIL" "$CPU_LOAD"

echoInfo "INFO: Discovering & Saving RAM util info..."
RAM_TOTAL=$(echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)" || echo -e "")
($(isNumber "$RAM_TOTAL")) && RAM_TOTAL=$(echo "scale=2; ( $RAM_TOTAL / 1 ) " | bc || echo -e "")
($(isNumber "$RAM_TOTAL")) && RAM_TOTAL="${RAM_TOTAL}%" || RAM_TOTAL=""
globSet RAM_UTIL "$RAM_TOTAL"

echoInfo "INFO: Discovering & Saving DISK util info..."
DISK_UTIL=""
DISK_USED=$(echo "$(df --output=used / | tail -n 1 | tr -d '[:space:]|%')" || echo -e "")
DISK_AVAIL=$(echo "$(df --output=avail / | tail -n 1 | tr -d '[:space:]|%')" || echo -e "")
if ($(isNaturalNumber "$DISK_USED")) && ($(isNaturalNumber "$DISK_AVAIL")) ; then
    DISK_UTIL=$(echo "scale=2; ( ( $DISK_USED * 100 ) / ( $DISK_AVAIL + $DISK_USED ) ) " | bc || echo -e "")
    ($(isNumber "$DISK_UTIL")) && DISK_UTIL="${DISK_UTIL}%" || DISK_UTIL=""
    [ "$DISK_UTIL" == "100.00%" ] && DISK_UTIL="100%"

    DISK_USED_OLD=$(globGet DISK_USED)
    ELAPSED=$(timerSpan DISK_CONS)
    if ($(isNaturalNumber "$DISK_USED_OLD")) && [ $ELAPSED -gt 0 ] ; then
        echoInfo "INFO: Discovering & Saving DISK consumption info..."
        DISK_CONS=$((($DISK_USED-$DISK_USED_OLD)/$ELAPSED))

        if [ $DISK_CONS -ge 1048576 ] || [ $DISK_CONS -le -1048576 ] ; then DISK_CONS=$(echo "scale=3; ( $DISK_CONS / 1048576 ) " | bc || echo -e "") && globSet DISK_CONS "$DISK_CONS MB/s"
        elif [ $DISK_CONS -gt 1024 ]  || [ $DISK_CONS -le -1024 ] ; then DISK_CONS=$(echo "scale=3; ( $DISK_CONS / 1024 ) " | bc || echo -e "") && globSet DISK_CONS "$DISK_CONS kB/s"
        else globSet DISK_CONS "$DISK_CONS B/s" ; fi
    fi

    globSet DISK_AVAIL "$DISK_AVAIL"
    globSet DISK_USED "$DISK_USED"
    globSet DISK_UTIL "$DISK_UTIL"
    timerStart "DISK_CONS"
fi

echoInfo "INFO: Discovering & Saving Public IP..."
PUBLIC_IP=$(timeout 10 bash -c ". /etc/profile && getPublicIp" 2> /dev/null || echo "")

echoInfo "INFO: Discovering & Saving Local IP..."
LOCAL_IP=$(timeout 10 bash -c ". /etc/profile && getLocalIp '$IFACE'" 2> /dev/null || echo "")

echoInfo "INFO: Updating IP addresses info..."
tryMkDir "$DOCKER_COMMON_RO"
tryMkDir "$GLOBAL_COMMON_RO"
($(isPublicIp "$PUBLIC_IP")) && globSet "PUBLIC_IP" "$PUBLIC_IP" && globSet "PUBLIC_IP" "$PUBLIC_IP" "$GLOBAL_COMMON_RO"
($(isIp "$LOCAL_IP")) && globSet "LOCAL_IP" "$LOCAL_IP" && globSet "LOCAL_IP" "$LOCAL_IP" "$GLOBAL_COMMON_RO"

echoInfo "INFO: Updating network speed info..."
LINE=$(grep "$(globGet IFACE)" /proc/net/dev | sed s/.*:// || echo -e "")
RECEIVED=$(echo $LINE | awk '{print $1}' || echo -e "")
TRANSMITTED=$(echo $LINE | awk '{print $9}' || echo -e "")

if ($(isNaturalNumber "$RECEIVED")) && ($(isNaturalNumber "$TRANSMITTED")) ; then
    NET_RECEIVED_OLD=$(globGet NET_RECEIVED)
    NET_TRANSMITTED_OLD=$(globGet NET_TRANSMITTED)
    NET_ELAPSED=$(timerSpan NET_CONS)
    
    if ($(isNaturalNumber "$NET_RECEIVED_OLD")) && ($(isNaturalNumber "$NET_TRANSMITTED_OLD")) && [ $NET_ELAPSED -gt 0 ] ; then
        NET_IN=$((($RECEIVED-$NET_RECEIVED_OLD)/$NET_ELAPSED))
        NET_OUT=$((($TRANSMITTED-$NET_TRANSMITTED_OLD)/$NET_ELAPSED))
        [ $NET_IN -ge $NET_OUT ] && IN_PRIORITY="true" || IN_PRIORITY="false"

        if [ $NET_IN -gt 1048576 ] ; then NET_IN=$(echo "scale=1; ( $NET_IN / 1048576 ) " | bc || echo -e "") && globSet NET_IN "$NET_IN MB/s"
        elif [ $NET_IN -gt 1024 ] ; then NET_IN=$(echo "scale=1; ( $NET_IN / 1024 ) " | bc || echo -e "") && globSet NET_IN "$NET_IN kB/s"
        else globSet NET_IN "$NET_IN B/s" ; fi

        if [ $NET_OUT -gt 1048576 ] ; then NET_OUT=$(echo "scale=1; ( $NET_OUT / 1048576 ) " | bc || echo -e "") && globSet NET_OUT "$NET_OUT MB/s"
        elif [ $NET_OUT -gt 1024 ] ; then NET_OUT=$(echo "scale=1; ( $NET_OUT / 1024 ) " | bc || echo -e "") && globSet NET_OUT "$NET_OUT kB/s"
        else globSet NET_OUT "$NET_OUT B/s" ; fi

        [ "$IN_PRIORITY" == "true" ] && globSet NET_PRIOR "↓$(globGet NET_IN)" || globSet NET_PRIOR "↑$(globGet NET_OUT)"
    fi

    globSet NET_RECEIVED "$RECEIVED"
    globSet NET_TRANSMITTED "$TRANSMITTED"
    timerStart NET_CONS
else
    echoWarn "WARNING: Could not determine link speed"
fi

#[ ! -z "$(globGet NET_PRIOR)" ] && sleep 45
#[ ! -z "$(globGet DISK_CONS)" ] && sleep 45

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HARDWARE MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x