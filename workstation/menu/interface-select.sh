#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/interface-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echoErr "Select your default internet connected network interface:"

[ -z "$IFACE" ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)
ifaces=( $ifaces_iterate )

i=-1
for f in $ifaces_iterate ; do
    i=$((i + 1))
    echo "[$i] $f"
done

OPTION=""
while : ; do
    read -p "Input interface number 0-$i (Default: $IFACE): " OPTION
    [ -z "$OPTION" ] && break
    ($(isNaturalNumber "$OPTION")) && [[ $OPTION -le $i ]] && break
done

[ ! -z "$OPTION" ] && IFACE=${ifaces[$OPTION]}

set +x
echoInfo "INFO: NETWORK interface '$IFACE' was selected"
echoNErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
set -x
CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True

echoInfo "INFO: MTU Value Discovery..."
MTU=$(cat /sys/class/net/$IFACE/mtu || echo "1500")
(! $(isNaturalNumber $MTU)) && MTU=1500
(($MTU < 100)) && MTU=900
globSet MTU $MTU