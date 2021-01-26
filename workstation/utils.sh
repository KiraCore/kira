#!/bin/bash

# QUICK EDIT: FILE="$KIRA_MANAGER/utils.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

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

function echoNInfo() {
    echo -en "\e[0m\e[36;1m${1}\e[0m"
}
function echoNWarn() {
    echo -en "\e[0m\e[33;1m${1}\e[0m"
}
function echoNErr() {
    echo -en "\e[0m\e[31;1m${1}\e[0m"
}