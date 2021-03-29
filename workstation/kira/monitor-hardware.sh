#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

START_TIME="$(date -u +%s)"

echo "INFO: Started kira hardware scan"

SCAN_DIR="$KIRA_HOME/kirascan"

DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"
RAM_SCAN_PATH="$SCAN_DIR/ram"

touch "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH" "$LIP_SCAN_PATH" "$IP_SCAN_PATH" 

CPU_LOAD=$(mpstat -o JSON -u 5 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}' || echo "")
echo "$CPU_LOAD" > $CPU_SCAN_PATH

RAM_TOTAL=$("$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%" || echo "")
echo "$RAM_TOTAL" > $RAM_SCAN_PATH

DISK_LEFT=$(echo "$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%")
echo "$DISK_LEFT" > $DISK_SCAN_PATH

PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 | awk -F'"' '{ print $2}' || echo "")
( ! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP=$(dig +short @resolver1.opendns.com myip.opendns.com +time=5 +tries=1 | awk -F'"' '{ print $1}' || echo "")
LOCAL_IP=$(/sbin/ifconfig $IFACE | grep -i mask | awk '{print $2}' | cut -f2 || echo "")
( ! $(isDnsOrIp "$LOCAL_IP")) && LOCAL_IP=$(hostname -I | awk '{ print $1}' || echo "0.0.0.0")

echo "$PUBLIC_IP" > $IP_SCAN_PATH
($(isDnsOrIp "$LOCAL_IP")) && echo "$LOCAL_IP" > $LIP_SCAN_PATH || echo "0.0.0.0" > $LIP_SCAN_PATH


echo "INFO: Updating IP addresses info..."
PUBLIC_IP=$(cat $IP_SCAN_PATH 2>/dev/null || echo "")
LOCAL_IP=$(cat $LIP_SCAN_PATH 2>/dev/null || echo "")
    
mkdir -p "$DOCKER_COMMON_RO"
    
($(isDnsOrIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" >"$DOCKER_COMMON_RO/public_ip"
($(isDnsOrIp "$LOCAL_IP")) && echo "$LOCAL_IP" >"$DOCKER_COMMON_RO/local_ip"
echo "INFO: Local and Public IP addresses were updated"

sleep 60 
