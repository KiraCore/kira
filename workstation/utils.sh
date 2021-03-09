#!/bin/bash
# QUICK EDIT: FILE="$KIRA_MANAGER/utils.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
REGEX_DNS="^(([a-zA-Z](-?[a-zA-Z0-9])*)\.)+[a-zA-Z]{2,}$"
REGEX_IP="^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$"
REGEX_NODE_ID="^[a-f0-9]{40}$"
REGEX_NUMBER="^[+-]?([0-9]*[.])?([0-9]+)?$"

function isDnsOrIp() {
    VTMP="false" && ( [[ "$1" =~ $REGEX_DNS ]] || [[ "$1" =~ $REGEX_IP ]] ) && VTMP="true"
    echo $VTMP
}

function isPort() {
     VTMP="false" && ( [[ "$1" =~ ^[0-9]+$ ]] && (($1 > 0 || $1 < 65536)) ) && VTMP="true"
     echo $VTMP
}

function isNodeId() {
     VTMP="false" && [[ "$1" =~ $REGEX_NODE_ID ]] && VTMP="true"
     echo $VTMP
}

function isNumber() {
     VTMP="false" && [[ "$1" =~ $REGEX_NUMBER ]] && VTMP="true"
     echo $VTMP
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