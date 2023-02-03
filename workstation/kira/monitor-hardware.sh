#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-hardware.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && fileFollow "$KIRA_LOGS/kirascan.log"
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
        # disk space consumtion in Bytes per second
        globSet DISK_CONS "$DISK_CONS"
    fi

    globSet DISK_AVAIL "$DISK_AVAIL"
    globSet DISK_USED "$DISK_USED"
    globSet DISK_UTIL "$DISK_UTIL"
    timerStart "DISK_CONS"
fi

echoInfo "INFO: Discovering & Saving Public IP..."
PUBLIC_IP=$(timeout 10 bu getPublicIp 2> /dev/null || echo "")

echoInfo "INFO: Discovering & Saving Local IP..."
LOCAL_IP=$(timeout 10 bu getLocalIp "$IFACE" 2> /dev/null || echo "0.0.0.0")

echoInfo "INFO: Updating IP addresses info..."
tryMkDir "$DOCKER_COMMON_RO"
tryMkDir "$GLOBAL_COMMON_RO"
($(isPublicIp "$PUBLIC_IP")) && globSet "PUBLIC_IP" "$PUBLIC_IP" && globSet "PUBLIC_IP" "$PUBLIC_IP" "$GLOBAL_COMMON_RO"
($(isIp "$LOCAL_IP")) && globSet "LOCAL_IP" "$LOCAL_IP" && globSet "LOCAL_IP" "$LOCAL_IP" "$GLOBAL_COMMON_RO"

echoInfo "INFO: Updating network speed info..."
LINE=$(grep "$IFACE" /proc/net/dev | sed s/.*:// || echo -e "")
RECEIVED=$(echo $LINE | awk '{print $1}' || echo -e "")
TRANSMITTED=$(echo $LINE | awk '{print $9}' || echo -e "")

if ($(isNaturalNumber "$RECEIVED")) && ($(isNaturalNumber "$TRANSMITTED")) ; then
    NET_RECEIVED_OLD=$(globGet NET_RECEIVED)
    NET_TRANSMITTED_OLD=$(globGet NET_TRANSMITTED)
    NET_ELAPSED=$(timerSpan NET_CONS)
    
    if ($(isNaturalNumber "$NET_RECEIVED_OLD")) && ($(isNaturalNumber "$NET_TRANSMITTED_OLD")) && [ $NET_ELAPSED -gt 0 ] ; then
        NET_IN=$((($RECEIVED-$NET_RECEIVED_OLD)/$NET_ELAPSED))
        NET_OUT=$((($TRANSMITTED-$NET_TRANSMITTED_OLD)/$NET_ELAPSED))
        globSet NET_IN "$NET_IN"
        globSet NET_OUT "$NET_OUT"
    fi

    globSet NET_RECEIVED "$RECEIVED"
    globSet NET_TRANSMITTED "$TRANSMITTED"
    timerStart NET_CONS
else
    globSet NET_IN ""
    globSet NET_OUT ""
    echoWarn "WARNING: Could not determine link speed"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HARDWARE MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x