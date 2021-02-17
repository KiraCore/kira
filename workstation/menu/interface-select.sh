#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e

echo -en "\e[31;1mPlease select your default internet connected network interface:\e[0m" && echo ""

[ -z "$IFACE" ] && IFACE=$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)
ifaces_iterate=$(ifconfig | cut -d ' ' -f1| tr ':' '\n' | awk NF)
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
    [[ $OPTION == ?(-)+([0-9]) ]] && [ $OPTION -ge 0 ] && [ $OPTION -le $i ] && break
done

if [ ! -z "$OPTION" ] ; then
    IFACE=${ifaces[$OPTION]}
fi

echo -en "\e[33;1mINFO: NETWORK interface '$IFACE' was selected\e[0m" && echo ""
echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
set -x
CDHelper text lineswap --insert="IFACE=$IFACE" --prefix="IFACE=" --path=$ETC_PROFILE --append-if-found-not=True

