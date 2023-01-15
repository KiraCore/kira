#!/usr/bin/env bash
set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="${COMMON_DIR}/configure.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
exec 2>&1
set -x

CFG="$INTERXD_HOME/config.json"

echoInfo "INFO: Updating CFG file..."
set -x
jsonAttributes $CFG > /tmp/cfg_names.tmp
mapfile cfg_rows < /tmp/cfg_names.tmp
set +x

for row in "${cfg_rows[@]}"; do
    ( $(isNullOrWhitespaces $row) ) && continue
    key=$(echo $row | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    val_target_1="cfg_$key"
    val_target_2=$(echo "$val_target_1" | sed -r 's/[.]+/_/g' | xargs)
    val="${!val_target_2}"
    [ -z "$val" ] && val=$(globGet "$val_target_1")
    [ -z "$val" ] && val=$(globGet "$val_target_2")

    if [ ! -z "$val" ] ; then
        echoWarn "WARNING: Updating CFG key: $key -> '$val' "
        jsonEdit "$key" "\"$val\"" $CFG $CFG
    else
        echoInfo "INFO: CFG key '$key' will NOT change, glob val NOT found"
    fi
done
