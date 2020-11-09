#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

# (rm -fv $KIRA_INFRA/docker/validator/scripts/export-account.sh) && nano $KIRA_INFRA/docker/validator/scripts/export-account.sh

NAME=$1
OUTPUT=$2
KEYRINGPASS=$3
PASSPHRASE=$4

echo -e "\e[33;1m------------------------------------------------"
echo "|       STARTED: EXPORT ACCOUNT v0.0.1         |"
echo "|----------------------------------------------|"
echo "|   NAME: $NAME"
echo "| OUTPUT: $OUTPUT"
echo -e "------------------------------------------------\e[0m"

ACC_ADDR=$(echo ${KEYRINGPASS} | sekaid keys show "$NAME" -a || echo "Error")

if [ "$ACC_ADDR" == "Error" ] ; then
    echo "ERROR: Export failed because account '$NAME' does NOT exists"
fi

DIRECTORY=$(dirname $OUTPUT)
mkdir -p $DIRECTORY

rm -f $OUTPUT
sekaid keys export $NAME --output text > $OUTPUT 2>&1 << EOF
$PASSPHRASE
$KEYRINGPASS
EOF

result=$(cat $OUTPUT)

if [ -z "$result" ] ; then
    echo "ERROR: Failed to export account '$NAME' into '$OUTPUT' file"
    exit 1
fi

echo "SUCCESS: Account '$NAME' was exported into '$OUTPUT' file"


echo "------------------------------------------------"
echo "|       FINISHED: EXPORT ACCOUNT v0.0.1        |"
echo "------------------------------------------------"