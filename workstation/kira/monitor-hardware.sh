#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-hardware.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat "$KIRA_SCAN/hardware.log"
set -x

timerStart

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA HARDWARE SCAN            |"
echoWarn "|-----------------------------------------------"
set -x

echoInfo "INFO: Discovering & Saving CPU load info..."
CPU_LOAD=$(mpstat -o JSON -u 4 1 | jsonQuickParse "idle" | awk '{print 100 - $1"%"}' || echo -e "")
globSet "CPU_UTIL" "$CPU_LOAD"
sleep 5

echoInfo "INFO: Discovering & Saving RAM util info..."
RAM_TOTAL=$(echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)" || echo -e "")
($(isNumber "$RAM_TOTAL")) && RAM_TOTAL=$(echo "scale=2; ( $RAM_TOTAL / 1 ) " | bc || echo -e "")
($(isNumber "$RAM_TOTAL")) && RAM_TOTAL="${RAM_TOTAL}%" || RAM_TOTAL=""
globSet "RAM_UTIL" "$RAM_TOTAL"
sleep 5

echoInfo "INFO: Discovering & Saving DISK util info..."
DISK_UTIL=""
DISK_USED=$(echo "$(df --output=used / | tail -n 1 | tr -d '[:space:]|%')" || echo -e "")
DISK_AVAIL=$(echo "$(df --output=avail / | tail -n 1 | tr -d '[:space:]|%')" || echo -e "")
if ($(isNaturalNumber "$DISK_USED")) && ($(isNaturalNumber "$DISK_AVAIL")) ; then
    DISK_UTIL=$(echo "scale=2; ( ( $DISK_USED * 100 ) / ( $DISK_AVAIL + $DISK_USED ) ) " | bc || echo -e "")
    ($(isNumber "$DISK_UTIL")) && DISK_UTIL="${DISK_UTIL}%" || DISK_UTIL=""

    DISK_USED_OLD=$(globGet DISK_USED)
    ELAPSED=$(timerSpan "DISK_CONS")
    if ($(isNaturalNumber "$DISK_USED_OLD")) && [ $ELAPSED -gt 0 ] ; then
        echoInfo "INFO: Discovering & Saving DISK consumption info..."
        DISK_SPAN=$(( $DISK_USED - $DISK_USED_OLD ))
        DISK_CONS=$(echo "scale=3; ( $DISK_SPAN / ( $ELAPSED * 1024 * 1024 ) ) " | bc || echo -e "")
        globSet "DISK_CONS" "${DISK_CONS} MB/s"
    fi
fi

globSet DISK_AVAIL "$DISK_AVAIL"
globSet DISK_USED "$DISK_USED"
globSet DISK_UTIL "$DISK_UTIL"
timerStart "DISK_CONS"
sleep 5

echoInfo "INFO: Discovering & Saving Public IP..."
PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 | awk -F'"' '{ print $2}' || echo -e "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @resolver1.opendns.com myip.opendns.com +time=5 +tries=1 | awk -F'"' '{ print $1}' || echo -e "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @ns1.google.com -t txt o-o.myaddr.l.google.com -4 | xargs || echo -e "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(timeout 3 curl https://ipinfo.io/ip | xargs || echo -e "")
sleep 5

echoInfo "INFO: Discovering & Saving Local IP..."
LOCAL_IP=$(/sbin/ifconfig $IFACE | grep -i mask | awk '{print $2}' | cut -f2 || echo -e "")
( ! $(isIp "$LOCAL_IP")) && LOCAL_IP=$(hostname -I | awk '{ print $1}' || echo -e "")
sleep 5

echoInfo "INFO: Updating IP addresses info..."
tryMkDir "$DOCKER_COMMON_RO"
($(isPublicIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" > "$DOCKER_COMMON_RO/public_ip" && globSet "PUBLIC_IP" "$PUBLIC_IP"
($(isIp "$LOCAL_IP")) && echo "$LOCAL_IP" > "$DOCKER_COMMON_RO/local_ip" && globSet "LOCAL_IP" "$LOCAL_IP"
sleep 5

echoInfo "INFO: Local and Public IP addresses were updated"
sleep 60

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HARDWARE MONITOR                   |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x