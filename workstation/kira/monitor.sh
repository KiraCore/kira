#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

SCAN_DIR="$KIRA_HOME/kirascan"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"

mkdir -p $SCAN_DIR

touch $CONTAINERS_SCAN_PATH
touch $NETWORKS_SCAN_PATH
touch $DISK_SCAN_PATH
touch $RAM_SCAN_PATH
touch $CPU_SCAN_PATH
touch $LIP_SCAN_PATH
touch $IP_SCAN_PATH

echo $(mpstat -o JSON -u 5 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}') > $CPU_SCAN_PATH &
echo $(docker network ls --format="{{.Name}}" || "") > $NETWORKS_SCAN_PATH
echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || "") > $CONTAINERS_SCAN_PATH
echo $(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=1 +tries=1 2> /dev/null | awk -F'"' '{ print $2}') > $IP_SCAN_PATH
echo $(/sbin/ifconfig $IFACE 2> /dev/null | grep -i mask 2> /dev/null | awk '{print $2}' 2> /dev/null | cut -f2 2> /dev/null || echo "0.0.0.0") > $LIP_SCAN_PATH
echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%" > $RAM_SCAN_PATH
echo "$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%" > $DISK_SCAN_PATH

wait

