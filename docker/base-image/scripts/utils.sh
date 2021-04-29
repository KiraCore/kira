#!/bin/bash
# QUICK EDIT: FILE="$SELF_SCRIPTS/utils.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
REGEX_DNS="^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$"
REGEX_IP="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
REGEX_NODE_ID="^[a-f0-9]{40}$"
REGEX_TXHASH="^[a-fA-F0-9]{64}$"
REGEX_INTEGER="^-?[0-9]+$"
REGEX_NUMBER="^[+-]?([0-9]*[.])?([0-9]+)?$"
REGEX_PUBLIC_IP='^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))(?<!127)(?<!^10)(?<!^0)\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!192\.168)(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!\.255$)(?<!\b255.255.255.0\b)(?<!\b255.255.255.242\b)$'

function isNullOrEmpty() {
    if [ -z "$1" ] || [ "${1,,}" == "null" ] ; then echo "true" ; else echo "false" ; fi
}

function isTxHash() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ "$1" =~ $REGEX_TXHASH ]] && VTMP="true"
        echo $VTMP
    fi
}

function isDns() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ "$1" =~ $REGEX_DNS ]] && VTMP="true"
        echo $VTMP
    fi
}

function isIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ "$1" =~ $REGEX_IP ]] && VTMP="true"
        echo $VTMP
    fi
}

function isPublicIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        if [ "$(echo "$1" | grep -P $REGEX_PUBLIC_IP | xargs || echo \"\")" == "$1" ] ; then
            echo "true"
        else
            echo "false"
        fi
    fi
}

function isDnsOrIp() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && ($(isDns "$1")) && VTMP="true"
        [ "$VTMP" != "true" ] && ($(isIp "$1")) && VTMP="true"
        echo $VTMP
    fi
}

function isInteger() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ $1 =~ $REGEX_INTEGER ]] && VTMP="true"
        echo $VTMP
    fi
}

function isBoolean() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        if [ "${1,,}" == "false" ] || [ "${1,,}" == "true" ] ; then echo "true"
        else echo "false" ; fi
    fi
}

function isPort() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && ( ($(isInteger $1)) && (($1 > 0 || $1 < 65536)) ) && VTMP="true"
        echo $VTMP
    fi
}

function isNodeId() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ "$1" =~ $REGEX_NODE_ID ]] && VTMP="true"
        echo $VTMP
    fi
}

function isNumber() {
     if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ "$1" =~ $REGEX_NUMBER ]] && VTMP="true"
        echo $VTMP
    fi
}

function isNaturalNumber() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && ($(isInteger "$1")) && [[ $1 -ge 0 ]] && VTMP="true"
        echo $VTMP
    fi
}

function isFileEmpty() {
    if [ -z "$1" ] || [ ! -f $1 ] || [ ! -s $1 ] ; then echo "true" ; else
        if [[ -z $(grep '[^[:space:]]' $1) ]] ; then
            echo "true"
        else
            echo "false"
        fi
    fi
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
        HEADS=$(echo "$1" | head -c 8)
        TAILS=$(echo "$1" | tail -c 8)
        STR=$(echo "${HEADS}${TAILS}" | tr -d '\n' | tr -d '\r' | tr -d '\a' | tr -d '\t' | tr -d ' ')
        if ($(isNullOrEmpty "$STR")) ; then echo "false"
        elif [[ "$STR" =~ ^\{.*\}$ ]] ; then echo "true"
        elif [[ "$STR" =~ ^\[.*\]$ ]] ; then echo "true"
        else echo "false"; fi
    fi
}

function isSimpleJsonObjOrArrFile() {
    if [ ! -f "$1" ] ; then echo "false"
    else
        HEADS=$(head -c 8 $1 2>/dev/null || echo -ne "")
        TAILS=$(tail -c 8 $1 2>/dev/null || echo -ne "")
        echo $(isSimpleJsonObjOrArr "${HEADS}${TAILS}")
    fi
}

function jsonParse() {
    QUERY="" && INPUT=$(echo $1 | xargs 2> /dev/null 2> /dev/null || echo -n "")
    FIN="" && [ ! -z "$2" ] && FIN=$(realpath $2 2> /dev/null || echo -n "")
    FOUT="" && [ ! -z "$3" ] && FOUT=$(realpath $3 2> /dev/null || echo -n "")
    if [ ! -z "$INPUT" ] ; then
        for k in ${INPUT//./ } ; do
            k=$(echo $k | xargs 2> /dev/null || echo -n "") && [ -z "$k" ] && continue
            [[ "$k" =~ ^\[.*\]$ ]] && QUERY="${QUERY}${k}" && continue
            ($(isNaturalNumber "$k")) && QUERY="${QUERY}[$k]" || QUERY="${QUERY}[\"$k\"]" 
        done
    fi
    if [ ! -z "$FIN" ] ; then
        if [ ! -z "$FOUT" ] ; then
            rm -f "$FOUT"
            python3 -c "import json,sys;fin=open('$FIN',\"r\");fout=open('$FOUT',\"w\",encoding=\"utf8\");obj=json.load(fin);json.dump(obj$QUERY,fout,separators=(',',':'),ensure_ascii=False);fin.close();fout.close()"
        else
            python3 -c "import json,sys;f=open('$FIN',\"r\");obj=json.load(f);print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));f.close()"
        fi
    else
        cat | python3 -c "import json,sys;obj=json.load(sys.stdin);print(json.dumps(obj$QUERY,separators=(',', ':'),ensure_ascii=False).strip(' \t\n\r\"'));"
    fi
}

function jsonQuickParse() {
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

# e.g. urlExists "18.168.78.192:11000/download/peers.txt"
function urlExists() {
    if ($(isNullOrEmpty "$1")) ; then echo "false"
    elif curl -r0-0 --fail --silent "$1" >/dev/null; then echo "true"
    else echo "false" ; fi
}

# TODO: Investigate 0 output
# urlContentLength 18.168.78.192:11000/download/snapshot.zip 
function urlContentLength() {
    VAL=$(curl --fail $1 --dump-header /dev/fd/1 --silent 2> /dev/null | grep -i Content-Length -m 1 2> /dev/null | awk '{print $2}' 2> /dev/null || echo -n "")
    # remove invisible whitespace characters
    VAL=$(echo ${VAL%$'\r'})
    (! $(isNaturalNumber $VAL)) && VAL=0
    echo $VAL
}

function prettyTime {
  local T=$1
  (! $(isNaturalNumber $T)) && T=0
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

displayAlign() {
  align=$1
  width=$2
  text=$3

  if [ $align == "center" ]; then
    textRight=$(((${#text} + $width) / 2))
    printf "|%*s %*s\n" $textRight "$text" $(($width - $textRight)) "|"
  elif [ $align == "left" ]; then
    textRight=$width
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