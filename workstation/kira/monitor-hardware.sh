#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-hardware.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"

set +x
echoWarn "------------------------------------------------"
echoWarn "|       STARTING KIRA HARDWARE SCAN            |"
echoWarn "|-----------------------------------------------"
echoWarn "|       SCAN_DIR: $SCAN_DIR"
echoWarn "| DISK_SCAN_PATH: $DISK_SCAN_PATH"
echoWarn "|  CPU_SCAN_PATH: $CPU_SCAN_PATH"
echoWarn "|  RAM_SCAN_PATH: $RAM_SCAN_PATH"
echoWarn "------------------------------------------------"
set -x

touch "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH"

CPU_LOAD=$(mpstat -o JSON -u 4 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}' || echo "")
echo "$CPU_LOAD" > $CPU_SCAN_PATH
sleep 2

RAM_TOTAL=$(echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%" || echo "")
echo "$RAM_TOTAL" > $RAM_SCAN_PATH
sleep 2

DISK_LEFT=$(echo "$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%")
echo "$DISK_LEFT" > $DISK_SCAN_PATH
sleep 2

PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 | awk -F'"' '{ print $2}' || echo "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @resolver1.opendns.com myip.opendns.com +time=5 +tries=1 | awk -F'"' '{ print $1}' || echo "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @ns1.google.com -t txt o-o.myaddr.l.google.com -4 | xargs || echo "")
( ! $(isPublicIp "$PUBLIC_IP")) && PUBLIC_IP=$(timeout 3 curl https://ipinfo.io/ip | xargs || echo "")
sleep 2

LOCAL_IP=$(/sbin/ifconfig $IFACE | grep -i mask | awk '{print $2}' | cut -f2 || echo "")
( ! $(isIp "$LOCAL_IP")) && LOCAL_IP=$(hostname -I | awk '{ print $1}' || echo "")
sleep 2

echo "INFO: Updating IP addresses info..."

mkdir -p "$DOCKER_COMMON_RO"
    
($(isPublicIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" > "$DOCKER_COMMON_RO/public_ip"
($(isIp "$LOCAL_IP")) && echo "$LOCAL_IP" > "$DOCKER_COMMON_RO/local_ip"

echo "INFO: Local and Public IP addresses were updated"
sleep 60


set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HARDWARE MONITOR                   |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x