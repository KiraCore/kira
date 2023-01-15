#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/interface-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echoErr "Select your default internet connected network interface:"

[ -z "$(globGet IFACE)" ] && globSet IFACE "$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)"
ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)
ifaces=( $ifaces_iterate )

i=-1
for f in $ifaces_iterate ; do
    i=$((i + 1))
    echo "[$i] $f"
done

OPTION=""
while : ; do
    read -p "Input interface number 0-$i (Default: $(globGet IFACE)): " OPTION
    [ -z "$OPTION" ] && break
    ($(isNaturalNumber "$OPTION")) && [[ $OPTION -le $i ]] && break
done

[ ! -z "$OPTION" ] && globSet IFACE "${ifaces[$OPTION]}"

set +x
echoInfo "INFO: NETWORK interface '$IFACE' was selected"
echoNErr "Press any key to continue or Ctrl+C to abort..." && pressToContinue
set -x

echoInfo "INFO: MTU Value Discovery..."
MTU=$(cat /sys/class/net/$(globGet IFACE)/mtu || echo "1500")
(! $(isNaturalNumber $MTU)) && MTU=1500
(($MTU < 100)) && MTU=900
globSet MTU $MTU