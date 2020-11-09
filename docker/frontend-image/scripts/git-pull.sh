#!/bin/bash

exec 2>&1
set -e

REPO=$1
BRANCH=$2
OUTPUT=$3
RWXMOD=$4

if [[ $BRANCH =~ ^[0-9A-Fa-f]{1,}$ ]] ; then
    CHECKOUT=$BRANCH
    BRANCH="master"
else
    CHECKOUT=""
fi

[ -z "$RWXMOD" ] && RWXMOD=777

echo "------------------------------------------------"
echo "|         STARTED: GIT PULL v0.0.1             |"
echo "------------------------------------------------"
echo "|      REPO:   $REPO"
echo "|    BRANCH:   $BRANCH"
echo "|  CHECKOUT:   $CHECKOUT"
echo "|    OUTPUT:   $OUTPUT"
echo "| R/W/X MOD:   $RWXMOD"
echo "------------------------------------------------"

if [[ (! -z "$REPO") && ( (! -z "$BRANCH") || (! -z "$CHECKOUT") ) && (! -z "$OUTPUT") ]] ; then
    echo "INFO: Valid repo details were specified, removing $OUTPUT and starting git pull..."
else
    [ -z "$REPO" ] && REPO=undefined
    [ -z "$BRANCH" ] && BRANCH=undefined
    [ -z "$CHECKOUT" ] && CHECKOUT=undefined
    [ -z "$OUTPUT" ] && OUTPUT=undefined
    echo "ERROR: REPO($REPO), BRANCH($BRANCH), CHECKOUT($CHECKOUT) or OUTPUT($OUTPUT) was NOT defined"
    exit 1
fi

rm -rf $OUTPUT
mkdir -p $OUTPUT

if [ ! -z "$BRANCH" ]
then
    git clone --branch $BRANCH $REPO $OUTPUT
else
    git clone $REPO $OUTPUT
fi

cd $OUTPUT

if [ ! -z "$CHECKOUT" ]
then
    git checkout $CHECKOUT
fi

git describe --tags || echo "No tags were found"
git describe --all --always

chmod -R $RWXMOD $OUTPUT

echo "------------------------------------------------"
echo "|         FINISHED: GIT PULL v0.0.1            |"
echo "------------------------------------------------"
