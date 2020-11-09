#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

# (rm -fv $KIRA_INFRA/docker/validator/scripts/add-account.sh) && nano $KIRA_INFRA/docker/validator/scripts/add-account.sh

NAME=$1
KEY=$2
KEYRINGPASS=$3
PASSPHRASE=$4
NEW_KEY=""

echo -e "\e[33;1m------------------------------------------------"
echo "|     STARTED: ADD OR IMPORT ACCOUNT v0.0.1    |"
echo "|----------------------------------------------|"
echo "| NAME: $NAME"
echo "|  KEY: $KEY"
echo -e "------------------------------------------------\e[0m"

# check common folder if key does not exists
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$COMMON_DIR/${KEY}"
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$COMMON_DIR/${KEY}.key" # use key as key filename
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$COMMON_DIR/${NAME}"
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$COMMON_DIR/${NAME}.key" # use name as key filename

# check configs directory  if key does not exists
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$SELF_CONFIGS/${KEY}"
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$SELF_CONFIGS/${KEY}.key" # use key as key filename
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$SELF_CONFIGS/${NAME}"
[ ! -f "$KEY" ] && [ ! -f "$NEW_KEY" ] && NEW_KEY="$SELF_CONFIGS/${NAME}.key" # use name as key filename

# replace kew with new key if substitute file was found
[ ! -f "$KEY" ] && [ -f "$NEW_KEY" ] && KEY="$NEW_KEY"

if [ -f "$KEY" ] ; then
   echo "INFO: Key $NAME ($KEY) was found and will be imported..."
   #  NOTE: external variables: KEYRINGPASS, PASSPHRASE
   #  NOTE: Exporting: sekaid keys export validator --output text
   #  NOTE: Deleting: sekaid keys delete validator
   #  NOTE: Importing (first time requires to input keyring password twice):
   sekaid keys import $NAME $KEY << EOF
$PASSPHRASE
$KEYRINGPASS
$KEYRINGPASS
EOF
else
   echo "WARNING: Generating NEW random $NAME key..."
   sekaid keys add $NAME << EOF
$KEYRINGPASS
$KEYRINGPASS
EOF
fi

echo "------------------------------------------------"
echo "|    FINISHED: ADD OR IMPORT ACCOUNT v0.0.1    |"
echo "------------------------------------------------"

