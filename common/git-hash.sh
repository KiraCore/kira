#!/usr/bin/env bash

exec 2>&1
set -e

REPO=$1

cd $REPO
BRANCH_REF=$(git rev-parse --abbrev-ref HEAD || echo -n "")

if [ -z "$BRANCH_REF" ] ; then
    echo "ERROR: Direcotry `$REPO` is not a git repository, failed to read the branch hash"
    echo 1
fi

FETCH="False" && $(git fetch origin $BRANCH_REF 2>/dev/null) && FETCH=True

if [ "$FETCH" == "False" ] ; then
    echo "ERROR: Failed to fetch lates changes from the `$REPO` repo `$BRANCH_REF` remote banch"
    echo 1
fi

HASH=$(git log -1 --format="%H" origin/$BRANCH_REF || echo -n "")

if [ -z "$HASH" ] ; then
    echo "ERROR: Failed to read hash of the `$BRANCH_REF` remote branch from the `$REPO` repo"
    echo 1
fi

echo "$HASH"

