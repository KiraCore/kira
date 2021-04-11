#!/bin/bash
# QUICK EDIT: FILE="$KIRA_MANAGER/utils.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
REGEX_DNS="^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$"
REGEX_IP="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
REGEX_NODE_ID="^[a-f0-9]{40}$"
REGEX_NUMBER="^[+-]?([0-9]*[.])?([0-9]+)?$"
REGEX_PUBLIC_IP='^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))(?<!127)(?<!^10)(?<!^0)\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!192\.168)(?<!172\.(16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31))\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(?<!\.255$)(?<!\b255.255.255.0\b)(?<!\b255.255.255.242\b)$'

function isNullOrEmpty() {
    if [ -z "$1" ] || [ "${1,,}" == "null" ] ; then echo "true" ; else echo "false" ; fi
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

function isPort() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && ( [[ "$1" =~ ^[0-9]+$ ]] && (($1 > 0 || $1 < 65536)) ) && VTMP="true"
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

function isInteger() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && [[ $1 =~ ^-?[0-9]+$ ]] && VTMP="true"
        echo $VTMP
    fi
}

function isNaturalNumber() {
    if ($(isNullOrEmpty "$1")) ; then echo "false" ; else
        VTMP="false" && ($(isInteger "$1")) && [ $1 -ge 0 ] && VTMP="true"
        echo $VTMP
    fi
}

function isFileEmpty() {
    if [ -z "$1" ] || [ ! -f "$1" ] || [ ! -s "$1" ] ; then echo "true" ; else
        if [[ -z $(grep '[^[:space:]]' $1) ]] ; then
            echo "true"
        else
            echo "false"
        fi
    fi
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