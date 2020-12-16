#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/git-pull.sh) && nano $KIRA_SCRIPTS/git-pull.sh && chmod 777 $KIRA_SCRIPTS/git-pull.sh

REPO=$1
BRANCH=$2
OUTPUT=$3
RWXMOD=$4
SSHCRED=$5

if [[ $BRANCH =~ ^[0-9A-Fa-f]{1,}$ ]] ; then
    CHECKOUT=$BRANCH
    BRANCH="master"
else
    CHECKOUT=""
fi

[ -z "$RWXMOD" ] && RWXMOD="default"
[ -z "$SSHCRED" ] && SSHCRED="/home/root/.ssh/id_rsa"

echo "------------------------------------------------"
echo "|         STARTED: GIT PULL v0.0.1             |"
echo "------------------------------------------------"
echo "|       REPO: $REPO"
echo "|     BRANCH: $BRANCH"
echo "|   CHECKOUT: $CHECKOUT"
echo "|     OUTPUT: $OUTPUT"
echo "|  R/W/X MOD: $RWXMOD"
echo "|   SSH CRED: $SSHCRED"
echo "------------------------------------------------"

TMP_OUTPUT="/tmp$OUTPUT"
if [[ (! -z "$REPO") && ( (! -z "$BRANCH") || (! -z "$CHECKOUT") ) && (! -z "$OUTPUT") ]] ; then
    echo "INFO: Valid repo details were specified, removing $TMP_OUTPUT, $OUTPUT and starting git pull..."
else
    [ -z "$REPO" ] && REPO=undefined
    [ -z "$BRANCH" ] && BRANCH=undefined
    [ -z "$CHECKOUT" ] && CHECKOUT=undefined
    [ -z "$OUTPUT" ] && OUTPUT=undefined
    echo "ERROR: REPO($REPO), BRANCH($BRANCH), CHECKOUT($CHECKOUT) or OUTPUT($OUTPUT) was NOT defined"
    exit 1
fi

mkdir -p $OUTPUT
mkdir -p "${KIRA_SETUP}${OUTPUT}"
REMOTE_HASH_FILE="$KIRA_SETUP$OUTPUT/remote_hash"
LOCAL_HASH_FILE="$KIRA_SETUP$OUTPUT/local_hash"

touch $REMOTE_HASH_FILE
touch $LOCAL_HASH_FILE

WKDIR=$PWD
cd $OUTPUT
LOCAL_HASH_NEW="$(hashdeep -r -l . | sort | md5sum | awk '{print $1}')"
LOCAL_HASH_OLD="$(cat $LOCAL_HASH_FILE)"
REMOTE_HASH_NEW=""
REMOTE_HASH_OLD="$(cat $REMOTE_HASH_FILE)"
cd $PWD

# make sure not to delete user files if there are no permissions for user to pull
rm -rf $TMP_OUTPUT
mkdir -p $TMP_OUTPUT

if [[ "${REPO,,}" == *"git@"* ]] ; then
    echo "INFO: Detected https repo address"

    if [ ! -z "$BRANCH" ] ; then
        ssh-agent sh -c "ssh-add $SSHCRED ; git clone --branch $BRANCH $REPO $TMP_OUTPUT"
    else
        ssh-agent sh -c "ssh-add $SSHCRED ; git clone $REPO $TMP_OUTPUT"
    fi

    cd $TMP_OUTPUT
    git remote set-url origin $REPO || echo "WARNING: Failed to set origin of the remote branch"

    if [ ! -z "$CHECKOUT" ] ; then
        ssh-agent sh -c "ssh-add $SSHCRED ; git checkout $CHECKOUT"
    fi
elif [[ "${REPO,,}" == *"https://"*   ]] ; then
    echo "INFO: Detected https repo address"
    
    if [ ! -z "$BRANCH" ] ; then
        echo "INFO: Fetching remote commit hash"
        REMOTE_HASH_NEW="$(git ls-remote $REPO $BRANCH | cut -c1-7)-${BRANCH}-${CHECKOUT}"
        
        if [ "$REMOTE_HASH_NEW" == "$REMOTE_HASH_OLD" ] && [ "$LOCAL_HASH_NEW" == "$LOCAL_HASH_OLD" ] ; then
            echo "INFO: Repo $REPO will NOT be cloned, no changes were detected"
            exit 0
        fi

        git clone --branch $BRANCH $REPO $TMP_OUTPUT
    else
        git clone $REPO $TMP_OUTPUT
    fi

    cd $TMP_OUTPUT
    git remote set-url origin $REPO || echo "WARNING: Failed to set origin of the remote branch"
    
    if [ ! -z "$CHECKOUT" ] ; then
        git checkout $CHECKOUT
    fi
else
    echo "ERROR: Invalid repo address, should be either https (https://) or ssh (git@)"
    exit 1
fi

ls -as

git describe --tags || echo "No tags were found"
git describe --all --always

[ -z "$OUTPUT" ] && echo "ERROR: Output location must be defined" && exit 1

rm -rf $OUTPUT
mkdir -p $OUTPUT
cp -rTfv "$TMP_OUTPUT" "$OUTPUT"

cd $OUTPUT
BRANCH_REF=$(git rev-parse --abbrev-ref HEAD || echo "$BRANCH")
git remote set-url origin $REPO || echo "WARNING: Failed to set origin of the remote branch"

if [[ "${REPO,,}" == *"git@"* ]] ; then
    ssh-agent sh -c "ssh-add $SSHCRED ; git fetch --all"
    ssh-agent sh -c "ssh-add $SSHCRED ; git reset --hard '@{u}'" || \
    ssh-agent sh -c "ssh-add $SSHCRED ; git reset --hard" || \
    echo "Failed to reset banch"
else
    git fetch --all
    git reset --hard '@{u}' || \
    git reset --hard || \
    echo "Failed to reset hard '@{u}' banch"
fi

REMOTE_HASH="$(git log -n1 --pretty='%h' || echo "undefined")-${BRANCH}-${CHECKOUT}"
LOCAL_HASH="$(hashdeep -r -l . | sort | md5sum | awk '{print $1}')"
echo "$REMOTE_HASH" > $REMOTE_HASH_FILE || rm -fv $REMOTE_HASH_FILE
echo "$LOCAL_HASH" > $LOCAL_HASH_FILE || rm -fv $LOCAL_HASH_FILE

ls -as
[ ! -z "$RWXMOD" ] && [ ! -z "${RWXMOD##*[!0-9]*}" ] && chmod -R $RWXMOD $OUTPUT

echo "------------------------------------------------"
echo "|         FINISHED: GIT PULL v0.0.1            |"
echo "|      COMMIT HASH: $REMOTE_HASH"
echo "|   DIRECTORY HASH: $LOCAL_HASH"
echo "------------------------------------------------"
