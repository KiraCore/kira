#!/bin/bash
# QUICK EDIT: FILE="$KIRA_MANAGER/utils.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
GLOB_STORE_DIR="/var/kiraglob"
REGEX_DNS="^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$"
REGEX_IP="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
REGEX_NODE_ID="^[a-f0-9]{40}$"
REGEX_TXHASH="^[a-fA-F0-9]{64}$"
REGEX_INTEGER="^-?[0-9]+$"
REGEX_NUMBER="^[+-]?([0-9]*[.])?([0-9]+)?$"
REGEX_PUBLIC_IP='^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))(?<!127)(?<!^10)(?<!^0)\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!192\.168)(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!\.255$)(?<!\b255.255.255.0\b)(?<!\b255.255.255.242\b)$'
REGEX_KIRA="^(kira)[a-zA-Z0-9]{39}$"

function isNullOrEmpty() {
    if [ -z "$1" ] || [ "${1,,}" == "null" ] ; then echo "true" ; else echo "false" ; fi
}

function delWhitespaces() {
    echo "$1" | tr -d '\011\012\013\014\015\040'
}

function isNullOrWhitespaces() {
    isNullOrEmpty $(delWhitespaces "$1")
}

function isKiraAddress() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_KIRA ]] && echo "true" || echo "false" ; fi
}

function isTxHash() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_TXHASH ]] && echo "true" || echo "false" ; fi
}

function isDns() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_DNS ]] && echo "true" || echo "false" ; fi
}

function isIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_IP ]] && echo "true" || echo "false" ; fi
}

function isPublicIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [ "$(echo "$1" | grep -P $REGEX_PUBLIC_IP | xargs || echo \"\")" == "$1" ] && echo "true" || echo "false" ; fi
}

function isDnsOrIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        kg_var="false" && ($(isDns "$1")) && kg_var="true"
        [ "$kg_var" != "true" ] && ($(isIp "$1")) && kg_var="true"
        echo $kg_var
    fi
}

function isInteger() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ $1 =~ $REGEX_INTEGER ]] && echo "true" || echo "false" ; fi
}

function isBoolean() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        if [ "${1,,}" == "false" ] || [ "${1,,}" == "true" ] ; then echo "true"
        else echo "false" ; fi
    fi
}

function isNodeId() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_NODE_ID ]] && echo "true" || echo "false" ; fi
}

function isNumber() {
     if ($(isNullOrEmpty "$1")) ; then echo "false" ; else [[ "$1" =~ $REGEX_NUMBER ]] && echo "true" || echo "false" ; fi
}

function isNaturalNumber() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else ( ($(isInteger "$1")) && [[ $1 -ge 0 ]] ) && echo "true" || echo "false" ; fi
}

function isLetters() {
    [[ "$1" =~ [^a-zA-Z] ]] && echo "false" || echo "true"
}

function isAlphanumeric() {
    [[ "$1" =~ [^a-zA-Z0-9] ]] && echo "false" || echo "true"
}

function isPort() {
    ( ($(isNaturalNumber $1)) && (($1 > 0)) && (($1 < 65536)) ) && echo "true" || echo "false"
}

function isMnemonic() {
    kg_mnem=$(echo "$1" | xargs 2> /dev/null || echo -n "")
    kg_count=$(echo "$kg_mnem" | wc -w 2> /dev/null || echo -n "")
    (! $(isNaturalNumber $kg_count)) && kg_count=0
    if (( $kg_count % 4 == 0 )) && [ $kg_count -ge 12 ] ; then echo "true" ; else echo "false" ; fi
}

function date2unix() {
    kg_date_tmp="$*" && kg_date_tmp=$(echo "$kg_date_tmp" | xargs 2> /dev/null || echo -n "")
    if (! $(isNullOrWhitespaces "$kg_date_tmp")) && (! $(isNaturalNumber $kg_date_tmp)) ; then
        kg_date_tmp=$(date -d "$kg_date_tmp" +"%s" 2> /dev/null || echo "0")
    fi

    ($(isNaturalNumber "$kg_date_tmp")) && echo "$kg_date_tmp" || echo "0"
}

function isPortOpen() {
    kg_addr=$1 && kg_port=$2 && kg_timeout=$3
    (! $(isNaturalNumber $kg_timeout)) && kg_timeout=1
    if (! $(isDnsOrIp $kg_addr)) || (! $(isPort $kg_port)) ; then echo "false"
    elif timeout $kg_timeout nc -z $kg_addr $kg_port ; then echo "true"
    else echo "false" ; fi
}

function fileSize() {
    kg_bytes=$(stat -c%s $1 2> /dev/null || echo -n "")
    ($(isNaturalNumber "$kg_bytes")) && echo "$kg_bytes" || echo -n "0"
}

function isFileEmpty() {
    if [ -z "$1" ] || [ ! -f $1 ] || [ ! -s $1 ] ; then echo "true" ; else
        kg_PREFIX_AND_SUFFIX=$(echo "$(head -c 64 $1 2>/dev/null || echo '')$(tail -c 64 $1 2>/dev/null || echo '')" | tr -d '\011\012\013\014\015\040' 2>/dev/null || echo -n "")
        if [ ! -z "$kg_PREFIX_AND_SUFFIX" ] ; then
            echo "false"
        else
            kg_TEXT=$(cat $1 | tr -d '\011\012\013\014\015\040' 2>/dev/null || echo -n "")
            [ -z "$kg_TEXT" ] && echo "true" || echo "false"
        fi
    fi
}

function sha256() {
    if [ -z "$1" ] ; then
        echo $(cat | sha256sum | awk '{ print $1 }' | xargs || echo -n "") || echo -n ""
    else
        [ -f $1 ] && echo $(sha256sum $1 | awk '{ print $1 }' | xargs || echo -n "") || echo -n ""
    fi
}

function md5() {
    if [ -z "$1" ] ; then
        echo $(cat | md5sum | awk '{ print $1 }' | xargs || echo -n "") || echo -n ""
    else
        [ -f $1 ] && echo $(md5sum $1 | awk '{ print $1 }' | xargs || echo -n "") || echo -n ""
    fi
}

function tryMkDir {
    for kg_var in "$@" ; do
        kg_var=$(echo "$kg_var" | tr -d '\011\012\013\014\015\040' 2>/dev/null || echo -n "")
        [ -z "$kg_var" ] && continue
        [ "${kg_var,,}" == "-v" ] && continue
        
        if [ -f "$kg_var" ] ; then
            if [ "${1,,}" == "-v" ] ; then
                rm -f "$kg_var" 2> /dev/null || : 
                [ ! -f "$kg_var" ] && echo "removed file '$kg_var'" || echo "failed to remove file '$kg_var'"
            else
                rm -f 2> /dev/null || :
            fi
        fi

        if [ "${1,,}" == "-v" ]  ; then
            [ ! -d "$kg_var" ] && mkdir -p "$var" 2> /dev/null || :
            [ -d "$kg_var" ] && echo "created directory '$kg_var'" || echo "failed to create direcotry '$kg_var'"
        elif [ ! -d "$kg_var" ] ; then
            mkdir -p "$kg_var" 2> /dev/null || :
        fi
    done
}

function tryCat {
    if ($(isFileEmpty $1)) ; then
        echo -ne "$2"
    else
        cat $1 2>/dev/null || echo -ne "$2"
    fi
}

function isDirEmpty() {
    if [ -z "$1" ] || [ ! -d "$1" ] || [ -z "$(ls -A "$1")" ] ; then echo "true" ; else
        echo "false"
    fi
}

function isSimpleJsonObjOrArr() {
    if ($(isNullOrEmpty "$1")) ; then echo "false"
    else
        kg_HEADS=$(echo "$1" | head -c 8)
        kg_TAILS=$(echo "$1" | tail -c 8)
        kg_STR=$(echo "${kg_HEADS}${kg_TAILS}" | tr -d '\n' | tr -d '\r' | tr -d '\a' | tr -d '\t' | tr -d ' ')
        if ($(isNullOrEmpty "$kg_STR")) ; then echo "false"
        elif [[ "$kg_STR" =~ ^\{.*\}$ ]] ; then echo "true"
        elif [[ "$kg_STR" =~ ^\[.*\]$ ]] ; then echo "true"
        else echo "false"; fi
    fi
}

function isSimpleJsonObjOrArrFile() {
    if [ ! -f "$1" ] ; then echo "false"
    else
        kg_HEADS=$(head -c 8 $1 2>/dev/null || echo -ne "")
        kg_TAILS=$(tail -c 8 $1 2>/dev/null || echo -ne "")
        echo $(isSimpleJsonObjOrArr "${kg_HEADS}${kg_TAILS}")
    fi
}

function jsonParse() {
    local QUERY=""
    local FIN=""
    local FOUT=""
    local INPUT=$(echo $1 | xargs 2> /dev/null 2> /dev/null || echo -n "")
    [ ! -z "$2" ] && FIN=$(realpath $2 2> /dev/null || echo -n "")
    [ ! -z "$3" ] && FOUT=$(realpath $3 2> /dev/null || echo -n "")
    if [ ! -z "$INPUT" ] ; then
        for k in ${INPUT//./ } ; do
            k=$(echo $k | xargs 2> /dev/null || echo -n "") && [ -z "$k" ] && continue
            [[ "$k" =~ ^\[.*\]$ ]] && QUERY="${QUERY}${k}" && continue
            ($(isNaturalNumber "$k")) && QUERY="${QUERY}[$k]" || QUERY="${QUERY}[\"$k\"]" 
        done
    fi
    if [ ! -z "$FIN" ] ; then
        if [ ! -z "$FOUT" ] ; then
            [ "$FIN" != "$FOUT" ] && rm -f "$FOUT" || :
            python3 -c "import json,sys;fin=open('$FIN',\"r\");obj=json.load(fin);fin.close();fout=open('$FOUT',\"w\",encoding=\"utf8\");json.dump(obj$QUERY,fout,separators=(',',':'),ensure_ascii=False);fout.close()"
        else
            python3 -c "import json,sys;f=open('$FIN',\"r\");obj=json.load(f);print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));f.close()"
        fi
    else
        cat | python3 -c "import json,sys;obj=json.load(sys.stdin);print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));"
    fi
}

function isFileJson() {
    if (! $(isFileEmpty "$1")) ; then
        jsonParse "" "$1" &> /dev/null && echo "true" || echo "false"
    else
        echo "false"
    fi
}

function jsonQuickParse() {
    local OUT=""
    if [ -z "$2" ] ; then
        OUT=$(cat | grep -Eo "\"$1\"[^,]*" 2> /dev/null | grep -Eo '[^:]*$' 2> /dev/null | xargs 2> /dev/null | awk '{print $1;}' 2> /dev/null 2> /dev/null)
    else
        ($(isFileEmpty $2)) && return 2
        OUT=$(grep -Eo "\"$1\"[^,]*" $2 2> /dev/null | grep -Eo '[^:]*$' 2> /dev/null | xargs 2> /dev/null | awk '{print $1;}' 2> /dev/null 2> /dev/null)
    fi
    OUT=${OUT%\}}
    ($(isNullOrEmpty "$OUT")) && return 1
    echo "$OUT"
}

function jsonEdit() {
    local QUERY=""
    local FIN=""
    local FOUT=""
    local INPUT=$(echo $1 | xargs 2> /dev/null 2> /dev/null || echo -n "")
    local VALUE="$2"
    [ ! -z "$3" ] && FIN=$(realpath $3 2> /dev/null || echo -n "")
    [ ! -z "$4" ] && FOUT=$(realpath $4 2> /dev/null || echo -n "")
    [ "${VALUE,,}" == "null" ] && VALUE="None"
    [ "${VALUE,,}" == "true" ] && VALUE="True"
    [ "${VALUE,,}" == "false" ] && VALUE="False"
    if [ ! -z "$INPUT" ] ; then
        for k in ${INPUT//./ } ; do
            k=$(echo $k | xargs 2> /dev/null || echo -n "") && [ -z "$k" ] && continue
            [[ "$k" =~ ^\[.*\]$ ]] && QUERY="${QUERY}${k}" && continue
            ($(isNaturalNumber "$k")) && QUERY="${QUERY}[$k]" || QUERY="${QUERY}[\"$k\"]" 
        done
    fi
    if [ ! -z "$FIN" ] ; then
        if [ ! -z "$FOUT" ] ; then
            [ "$FIN" != "$FOUT" ] && rm -f "$FOUT" || :
            python3 -c "import json,sys;fin=open('$FIN',\"r\");obj=json.load(fin);obj$QUERY=$VALUE;fin.close();fout=open('$FOUT',\"w\",encoding=\"utf8\");json.dump(obj,fout,separators=(',',':'),ensure_ascii=False);fout.close()"
        else
            python3 -c "import json,sys;f=open('$FIN',\"r\");obj=json.load(f);obj$QUERY=$VALUE;print(json.dumps(obj,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));f.close()"
        fi
    else
        cat | python3 -c "import json,sys;obj=json.load(sys.stdin);obj$QUERY=$VALUE;print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));"
    fi
}

function jsonObjEdit() {
    local QUERY=""
    local FVAL=""
    local FIN=""
    local FOUT=""
    local INPUT=$(echo $1 | xargs 2> /dev/null 2> /dev/null || echo -n "")
    [ ! -z "$2" ] && FVAL=$(realpath $2 2> /dev/null || echo -n "")
    [ ! -z "$3" ] && FIN=$(realpath $3 2> /dev/null || echo -n "")
    [ ! -z "$4" ] && FOUT=$(realpath $4 2> /dev/null || echo -n "")
    [ "${VALUE,,}" == "null" ] && VALUE="None"
    [ "${VALUE,,}" == "true" ] && VALUE="True"
    [ "${VALUE,,}" == "false" ] && VALUE="False"
    if [ ! -z "$INPUT" ] ; then
        for k in ${INPUT//./ } ; do
            k=$(echo $k | xargs 2> /dev/null || echo -n "") && [ -z "$k" ] && continue
            [[ "$k" =~ ^\[.*\]$ ]] && QUERY="${QUERY}${k}" && continue
            ($(isNaturalNumber "$k")) && QUERY="${QUERY}[$k]" || QUERY="${QUERY}[\"$k\"]" 
        done
    fi
    if [ ! -z "$FIN" ] ; then
        if [ ! -z "$FOUT" ] ; then
            [ "$FIN" != "$FOUT" ] && rm -f "$FOUT" || :
            python3 -c "import json,sys;fin=open('$FIN',\"r\");fin2=open('$FVAL',\"r\");obj2=json.load(fin2);obj=json.load(fin);obj$QUERY=obj2;fin.close();fout=open('$FOUT',\"w\",encoding=\"utf8\");json.dump(obj,fout,separators=(',',':'),ensure_ascii=False);fin2.close();fout.close()" || SUCCESS="false"
        else
            python3 -c "import json,sys;f=open('$FIN',\"r\");fin2=open('$FVAL',\"r\");obj2=json.load(fin2);obj=json.load(f);obj$QUERY=obj2;print(json.dumps(obj,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));f.close();fin2.close()"
        fi
    else
        cat | python3 -c "import json,sys;obj=json.load(sys.stdin);fin2=open('$FVAL',\"r\");obj2=json.load(fin2);obj$QUERY=obj2;print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));fin2.close()"
    fi
}

# e.g. urlExists "18.168.78.192:11000/download/peers.txt"
function urlExists() {
    if ($(isNullOrEmpty "$1")) ; then echo "false"
    elif curl -r0-0 --fail --silent "$1" >/dev/null; then echo "true"
    else echo "false" ; fi
}

# TODO: Investigate 0 output
# urlContentLength 18.168.78.192:11000/download/snapshot.tar 
function urlContentLength() {
    local VAL=$(curl --fail $1 --dump-header /dev/fd/1 --silent 2> /dev/null | grep -i Content-Length -m 1 2> /dev/null | awk '{print $2}' 2> /dev/null || echo -n "")
    # remove invisible whitespace characters
    VAL=$(echo ${VAL%$'\r'})
    (! $(isNaturalNumber $VAL)) && VAL=0
    echo $VAL
}

function globName() {
    echo $(echo "${1,,}" | tr -d '\011\012\013\014\015\040' | md5sum | awk '{ print $1 }')
    return 0
}

function globFile() {
    if [ ! -z "$2" ] && [ -d $2 ] ; then
        echo "${2}/$(globName $1)"
    else echo "${GLOB_STORE_DIR}/$(globName $1)" ; fi
    return 0
}

function globGet() {
    local kg_FIL=$(globFile "$1" "$2")
    [[ -s $kg_FIL ]] && cat $kg_FIL || echo ""
    return 0
}

# threadsafe global get
function globGetTS() {
    local kg_FIL=$(globFile "$1" "$2")
    [[ -s "$kg_FIL" ]] && sem --id $1 "cat $kg_FIL" || echo ""
    return 0
}

function globSet() {
    local kg_FIL=""
    [ ! -z "$3" ] && kg_FIL=$(globFile "$1" "$3") || kg_FIL=$(globFile "$1")
    touch "$kg_FIL.tmp"
    [ ! -z ${2+x} ] && echo "$2" > "$kg_FIL.tmp" || cat > "$kg_FIL.tmp"
    mv -f "$kg_FIL.tmp" $kg_FIL
}

# threadsafe global set
function globSetTS() {
    local kg_FIL=""
    [ ! -z "$3" ] && kg_FIL=$(globFile "$1" "$3") || kg_FIL=$(globFile "$1")
    touch "$kg_FIL"
    [ ! -z ${2+x} ] &&  sem --id $kg_NAM "echo $2 > $kg_FIL" || sem --id $kg_NAM --pipe "cat > $kg_FIL"
}

function globEmpty() {
    ($(isFileEmpty $(globFile "$1" "$2"))) && echo "true" || echo "false"
}

function globDel {
    for kg_var in "$@" ; do
        [ -z "$kg_var" ] && continue
        globSet "$kg_var" ""
    done
}

function timerStart() {
    [ "${1,,}" == "-v" ] && kg_NAME=$2 || kg_NAME=$1
    [ -z "$kg_NAME" ] && kg_NAME="${BASH_SOURCE}"
    kg_TIME="$(date -u +%s)"
    globSet "timer_start_${kg_NAME}" "$kg_TIME"
    globSet "timer_stop_${kg_NAME}" ""
    [ "${1,,}" == "-v" ] && echo "$kg_TIME"
    return 0
}

function timerStop() {
    [ "${1,,}" == "-v" ] && kg_NAME=$2 || kg_NAME=$1
    [ -z "$kg_NAME" ] && kg_NAME="$BASH_SOURCE"
    kg_NAME="timer_stop_${kg_NAME}"
    ($(globEmpty "$NAME")) && globSet "$kg_NAME" "$(date -u +%s)"
    [ "${1,,}" == "-v" ] && globGet "$kg_NAME"
    return 0
}

# if VMAX is set then time left until VMAX is calculated
function timerSpan() {
    kg_NAME=$1 && [ -z "$kg_NAME" ] && kg_NAME="$BASH_SOURCE"
    kg_VMAX=$2
    ($(isNaturalNumber $kg_VMAX)) && kg_CALC_TIME_LEFT="true" || kg_CALC_TIME_LEFT="false"
    kg_START_TIME=$(globGet "timer_start_${kg_NAME}")
    kg_END_TIME=$(globGet "timer_stop_${kg_NAME}")
    if (! $(isNaturalNumber "$kg_START_TIME")) ; then
        kg_ELAPSED=0
    elif (! $(isNaturalNumber "$kg_END_TIME")) ; then 
        kg_ELAPSED="$(($(date -u +%s) - $kg_START_TIME))"
    else
        kg_ELAPSED="$(($kg_END_TIME - $kg_START_TIME))"
    fi

    if ($(isNaturalNumber $kg_VMAX)) ; then
        kg_TDELTA=$(($kg_VMAX - $kg_ELAPSED))
        [[ $kg_TDELTA -lt 0 ]] && kg_TDELTA=0
        echo $kg_TDELTA
    else
        echo $kg_ELAPSED
    fi
    return 0
}

function timerDel() {
    if [ -z "$@" ] ; then
        kg_var="$BASH_SOURCE"
        globSet "timer_start_${kg_var}" ""
        globSet "timer_stop_${kg_var}" ""
    else
        for kg_var in "$@" ; do
            [ -z "$kg_var" ] && kg_var="$BASH_SOURCE"
            globSet "timer_start_${kg_var}" ""
            globSet "timer_stop_${kg_var}" ""
        done
    fi
    return 0
}

function prettyTime {
  local T=$(date2unix "$1")
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && (( $D > 1 )) && printf '%d days ' $D
  (( $D > 0 )) && (( $D < 2 )) && printf '%d day ' $D
  (( $H > 0 )) && (( $H > 1 )) && printf '%d hours ' $H
  (( $H > 0 )) && (( $H < 2 )) && printf '%d hour ' $H
  (( $M > 0 )) && (( $M > 1 )) && printf '%d minutes ' $M
  (( $M > 0 )) && (( $M < 2 )) && printf '%d minute ' $M
  (( $S != 1 )) && printf '%d seconds\n' $S || printf '%d second\n' $S
}

function prettyTimeSlim {
  local T=$(date2unix "$1")
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && (( $D > 1 )) && printf '%dd ' $D
  (( $D > 0 )) && (( $D < 2 )) && printf '%dd ' $D
  (( $H > 0 )) && (( $H > 1 )) && printf '%dh ' $H
  (( $H > 0 )) && (( $H < 2 )) && printf '%dh ' $H
  (( $M > 0 )) && (( $M > 1 )) && printf '%dm ' $M
  (( $M > 0 )) && (( $M < 2 )) && printf '%dm ' $M
  (( $S != 1 )) && printf '%ds\n' $S || printf '%ds\n' $S
}

function resolveDNS {
    if ($(isIp "$1")) ; then
        echo "$1"
    else
        local kg_dns=$(timeout 10 dig +short "$1" 2> /dev/null || echo -e "")
        ($(isIp $kg_dns)) && echo $kg_dns || echo -e ""
    fi
}

function isSubStr {
    local STR=$1
    local SUB=$2
    [[ $STR == *"$SUB"* ]] && echo "true" || echo "false"
}

function isCommand {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; elif command -v "$1" &> /dev/null ; then echo "true" ; else echo "false" ; fi
}

function isServiceActive {
    local ISACT=$(systemctl is-active "$1" 2> /dev/null || echo "inactive")
    [ "${ISACT,,}" == "active" ] && echo "true" || echo "false"
}

# returns 0 if failure, otherwise natural number in microseconds
function pingTime() {
    if ($(isDnsOrIp "$1")) ; then
        local PAVG=$(ping -qc1 "$1" 2>&1 | awk -F'/' 'END{ print (/^rtt/? $5:"FAIL") }' 2> /dev/null || echo -n "")
        if ($(isNumber $PAVG)) ; then
            local PAVGUS=$(echo "scale=3; ( $PAVG * 1000 )" | bc 2> /dev/null || echo -n "")
            PAVGUS=$(echo "scale=0; ( $PAVGUS / 1 ) " | bc 2> /dev/null || echo -n "")
            ($(isNaturalNumber $PAVGUS)) && echo "$PAVGUS" || echo "0"
        else echo "0" ; fi
    else echo "0" ; fi
}

function pressToContinue {
    if ($(isNullOrEmpty "$1")) ; then
        read -n 1 -s 
        globSet OPTION ""
    else
        while : ; do
            local kg_OPTION=""
            local FOUND=false
            read -n 1 -s kg_OPTION
            kg_OPTION="${kg_OPTION,,}"
            for kg_var in "$@" ; do
                kg_var=$(echo "$kg_var" | tr -d '\011\012\013\014\015\040' 2>/dev/null || echo -n "")
                [ "${kg_var,,}" == "$kg_OPTION" ] && globSet OPTION "$kg_OPTION" && FOUND=true && break
            done
            [ "$FOUND" == "true" ] && break
        done
    fi
    echo ""
}

displayAlign() {
    local align=$1
    local width=$2
    local text=$3

    if [ $align == "center" ]; then
        local textRight=$(((${#text} + $width) / 2))
        printf "|%*s %*s\n" $textRight "$text" $(($width - $textRight)) "|"
    elif [ $align == "left" ]; then
        local textRight=$width
        printf "|%-*s|\n" $textRight "$text"
    fi
}

function echoInfo() {
    echo -e "\e[0m\e[36;1m${1}\e[0m"
}
function echoWarn() {
    echo -e "\e[0m\e[33;1m${1}\e[0m"
}
function echoErr() {
    echo -e "\e[0m\e[31;1m${1}\e[0m"
}
function echoInf() {
    echoInfo "${1}"
}
function echoWarning() {
    echoWarn "${1}"
}
function echoError() {
    echoErr "${1}"
}

function echoNInfo() {
    echo -en "\e[0m\e[36;1m${1}\e[0m"
}
function echoNWarn() {
    echo -en "\e[0m\e[33;1m${1}\e[0m"
}
function echoNErr() {
    echo -en "\e[0m\e[31;1m${1}\e[0m"
}
function echoNInf() {
    echoNInfo "${1}"
}
function echoNWarning() {
    echoNWarn "${1}"
}
function echoNError() {
    echoNErr "${1}"
}

# echo command with a line number
function echol() {
    grep -n "$1" $0 |  sed "s/echo_line_no//" 
}