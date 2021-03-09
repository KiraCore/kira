#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-valinfo.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

SCAN_DIR="$KIRA_HOME/kirascan"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALOPERS_SCAN_PATH="$SCAN_DIR/valopers"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
VALINFO_SCAN_PATH="$SCAN_DIR/valinfo"

touch "$VALADDR_SCAN_PATH" "$VALSTATUS_SCAN_PATH" "$VALOPERS_SCAN_PATH" "$VALINFO_SCAN_PATH"

echo "INFO: Saving valopers info..."
VALOPERS=$(timeout 5 wget -qO- "$KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/valopers?all=true" | jq -rc || echo "")
echo "$VALOPERS" > $VALOPERS_SCAN_PATH

if [[ "${INFRA_MODE,,}" =~ ^(validator|local)$ ]] ; then
    echo "INFO: Validator info will the scanned..."
else
    echo "" > $VALINFO_SCAN_PATH
    echo "" > $VALADDR_SCAN_PATH
    echo "" > $VALSTATUS_SCAN_PATH
    exit 0
fi

VALADDR=$(docker exec -i validator sekaid keys show validator -a --keyring-backend=test || echo "")
[ ! -z "$VALADDR" ] && VALSTATUS=$(docker exec -i validator sekaid query validator --addr=$VALADDR --output=json || echo "") || VALSTATUS=""

if [ -z "$VALADDR" ] || [ -z "$VALSTATUS" ] ; then
    echo "" > $VALINFO_SCAN_PATH
    echo "" > $VALADDR_SCAN_PATH
    echo "" > $VALSTATUS_SCAN_PATH
fi

VRANK=$(echo $VALSTATUS | jq -rc '.rank' 2> /dev/null || echo "")
VALIDATORS=$(echo $VALOPERS 2> /dev/null | jq -rc '.validators|=sort_by(.rank)|.validators|reverse' 2> /dev/null || echo "")

if $(isNumber "$VRANK") && [ ! -z "$VALIDATORS" ] ; then
    i=0
    for row in $(echo "$VALIDATORS" 2> /dev/null | jq -rc '.[] | @base64' 2> /dev/null || echo ""); do
        i=$((i+1))
        vobj=$(echo ${row} | base64 --decode 2> /dev/null | jq -rc 2> /dev/null || echo "")
        vaddr=$(echo "$vobj" 2> /dev/null | jq -rc '.address' 2> /dev/null || echo "")
        if [ "$VALADDR" == "$vaddr" ] ; then
            vobj=$(echo "$vobj" | jq -rc ". += {\"top\": \"$i\"}" || echo "")
            echo "$vobj" > $VALINFO_SCAN_PATH
            exit 0
        fi
    done
fi

echo "" > $VALINFO_SCAN_PATH

sleep 60