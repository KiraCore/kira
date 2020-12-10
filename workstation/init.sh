#!/bin/bash

SKIP_UPDATE=$1
START_TIME_INIT=$2
DEBUG_MODE=$3
INTERACTIVE=$4

echo "------------------------------------------------"
echo "| STARTED: INIT                                |"
echo "|-----------------------------------------------"
echo "| SKIP UPDATE: $SKIP_UPDATE"
echo "|  START_TIME: $START_TIME_INIT"
echo "|  DEBUG MODE: $DEBUG_MODE"
echo "| INTERACTIVE: $INTERACTIVE"
echo "------------------------------------------------"

ETC_PROFILE="/etc/profile"
SETUP_VER="v0.0.10" # Used To Initialize Essential, Needs to be iterated if essentials must be updated
INFRA_BRANCH="KIP_51"
SETUP_LOG="$HOME/setup.log"

set +e # prevent potential infinite loop

chmod 555 $ETC_PROFILE
source $ETC_PROFILE &>/dev/null

set -e

if [ -z "$SKIP_UPDATE" ]; then
   exec &> >(tee "$SETUP_LOG")
   echo "MMMMMMMMMMMMMWWNNWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMWX0kdloxOKNWMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMWNKOxlc::::::cok0XWWMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMWX0kdlc::::::::::::clxkOKNMMMMMMMMMMWKkk0NWMMMM"
   echo "MMNkoc:::::::::::::::::::::cok0NWMMMMMMWKxlcld0NMM"
   echo "MW0l:cllc:::::::::::::::::::::coKWMMMMMMMWKo:;:xNM"
   echo "MWOlcxXNKOdlc::::::::::::::::::l0WMMMMMWNKxc;;;oXM"
   echo "MW0olOWMMMWX0koc::::::::::::ldOXWMMMWXOxl:;;;;;oXM"
   echo "MMWXKNMMMMMMMWNKOdl::::codk0NWMMWNKkdc:;;;;;;;;oXM"
   echo "MMMMMMMMMMMMMMMMMWX0kkOKNWMMMWX0xl:;;;;;;;;;;;;oXM"
   echo "MMMMMMMMMMWXOkOKNMMMMMMMMMMMW0l:;;;;;;;;;;;;;;;oXM"
   echo "MMMMMMMMMMXo:::cox0XWMMMMMMMNx:;;;;;;;;;;;;;;;;oXM"
   echo "MMMMMMMMMMKl:::::::ldOXWMMMMNx:;;;;;;;;;;;;;;co0WM"
   echo "MMMMMMMMMMKl::::;;;;;:ckWMMMNx:;;;;;;;;;;:ldOKNMMM"
   echo "MMMMMMMMMMKl;;;;;;;;;;;dXMMMNx:;;;;;;;:ox0XWMMMMMM"
   echo "MMMMMMMMMMKl;;;;;;;;;;;dXMMMWk:;;;:cdkKNMMMMMMMMMM"
   echo "MMMMMMMMMMKl;;;;;;;;;;;dXMMMMXkoox0XWMMMMMMMMMMMMM"
   echo "MMMMMMMMMMKl;;;;;;;;;;;dXMMMMMWWWMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMKl;;;;;;;;;;;dXMMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMKo;;;;;;;;;;;dXMMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMWKxl:;;;;;;;;oXMMMWNWMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMMMWNKkdc;;;;;:dOOkdlkNMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMMMMMMMWXOxl:;;;;;cokKWMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMMMMMMMMMMWN0kdxxOKWMMMMMMMMMMMMMMMMMMMMM"
   echo "MMMMMMMMMMMMMMMMMMMMMMMWWMMMMMMMMMMMMMMMMMMMMMMMMM"
   echo "M          KIRA NETWORK SETUP $SETUP_VER"
   echo "MMMMMMMMMMMMMMMMMMMMMMMWWMMMMMMMMMMMMMMMMMMMMMMMMM"
   sleep 3
else
   exec &> >(tee -a "$SETUP_LOG")
   echo "INFO: Initalizing setup script..."
fi

[ -z "$START_TIME_INIT" ] && START_TIME_INIT="$(date -u +%s)"
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"
[ -z "$DEBUG_MODE" ] && DEBUG_MODE="False"
[ -z "$SILENT_MODE" ] && SILENT_MODE="False"
[ -z "$INTERACTIVE" ] && INTERACTIVE="True"

# in the non interactive mode always use explicit shell
[ "$INTERACTIVE" != "True" ] && set -x
[ -z "$KIRA_STOP" ] && KIRA_STOP="False"

[ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH="v0.1.7.4"
[ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH="dev"
[ -z "$KMS_BRANCH" ] && KMS_BRANCH="develop"
[ -z "$INTERX_BRANCH" ] && INTERX_BRANCH="KIP_31"

[ -z "$INFRA_REPO" ] && INFRA_REPO="https://github.com/KiraCore/kira"
[ -z "$SEKAI_REPO" ] && SEKAI_REPO="https://github.com/KiraCore/sekai"
[ -z "$FRONTEND_REPO" ] && FRONTEND_REPO="https://github.com/KiraCore/kira-frontend"
[ -z "$KMS_REPO" ] && KMS_REPO="https://github.com/iqlusioninc/tmkms"
[ -z "$INTERX_REPO" ] && INTERX_REPO="https://github.com/KiraCore/sekai"

[ ! -z "$SUDO_USER" ] && KIRA_USER=$SUDO_USER
[ -z "$KIRA_USER" ] && KIRA_USER=$USER
[ "$KIRA_USER" == "root" ] && KIRA_USER=$(logname)
if [ "$KIRA_USER" == "root" ]; then
    echo "ERROR: You must login as non root user to your machine!"
    exit 1
fi

if [ "$SKIP_UPDATE" == "False" ]; then

    # in the non interactive mode always use explicit shell
    [ "$INTERACTIVE" != "True" ] && set -x

    #########################################
    # START Installing Essentials
    #########################################
    KIRA_REPOS=/kira/repos

    KIRA_INFRA="$KIRA_REPOS/kira"
    KIRA_SEKAI="$KIRA_REPOS/sekai"
    KIRA_FRONTEND="$KIRA_REPOS/frontend"
    KIRA_KMS="$KIRA_REPOS/kms"
    KIRA_INTERX="$KIRA_REPOS/interx"

    KIRA_SETUP=/kira/setup
    KIRA_MANAGER="/kira/manager"
    KIRA_PROGRESS="/kira/progress"
    KIRA_DUMP="/home/$KIRA_USER/Desktop/DUMP"
    KIRA_SCRIPTS="${KIRA_INFRA}/common/scripts"
    KIRA_WORKSTATION="${KIRA_INFRA}/workstation"

    mkdir -p $KIRA_INFRA
    mkdir -p $KIRA_SEKAI
    mkdir -p $KIRA_FRONTEND
    mkdir -p $KIRA_KMS
    mkdir -p $KIRA_INTERX

    mkdir -p $KIRA_SETUP
    mkdir -p $KIRA_MANAGER
    mkdir -p $KIRA_PROGRESS
    rm -rfv $KIRA_DUMP
    mkdir -p "$KIRA_DUMP/INFRA/manager"

    KIRA_SETUP_ESSSENTIALS="$KIRA_SETUP/essentials-$SETUP_VER"
    if [ ! -f "$KIRA_SETUP_ESSSENTIALS" ]; then
        echo "INFO: Installing Essential Packages and Variables..."
        apt-get update -y >/dev/null
        apt-get install -y --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
            software-properties-common apt-transport-https ca-certificates gnupg curl wget git unzip >/dev/null

        ln -s /usr/bin/git /bin/git || echo "WARNING: Git symlink already exists"

        echo "INFO: Base Tools Setup..."
        cd /tmp
        INSTALL_DIR="/usr/local/bin"
        rm -f -v ./CDHelper-linux-x64.zip
        wget https://github.com/asmodat/CDHelper/releases/download/v0.6.13/CDHelper-linux-x64.zip
        rm -rfv $INSTALL_DIR
        unzip CDHelper-linux-x64.zip -d $INSTALL_DIR
        chmod -R -v 777 $INSTALL_DIR

        ls -l /bin/CDHelper || echo "Symlink not found"
        rm /bin/CDHelper || echo "Removing old symlink"
        ln -s $INSTALL_DIR/CDHelper/CDHelper /bin/CDHelper || echo "CDHelper symlink already exists"

        CDHelper version

        CDHelper text lineswap --insert="KIRA_MANAGER=$KIRA_MANAGER" --prefix="KIRA_MANAGER=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_REPOS=$KIRA_REPOS" --prefix="KIRA_REPOS=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_SETUP=$KIRA_SETUP" --prefix="KIRA_SETUP=" --path=$ETC_PROFILE --append-if-found-not=True

        CDHelper text lineswap --insert="KIRA_INFRA=$KIRA_INFRA" --prefix="KIRA_INFRA=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_SEKAI=$KIRA_SEKAI" --prefix="KIRA_SEKAI=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_FRONTEND=$KIRA_FRONTEND" --prefix="KIRA_FRONTEND=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_KMS=$KIRA_KMS" --prefix="KIRA_KMS=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_INTERX=$KIRA_INTERX" --prefix="KIRA_INTERX=" --path=$ETC_PROFILE --append-if-found-not=True

        CDHelper text lineswap --insert="KIRA_SCRIPTS=$KIRA_SCRIPTS" --prefix="KIRA_SCRIPTS=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_WORKSTATION=$KIRA_WORKSTATION" --prefix="KIRA_WORKSTATION=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="KIRA_SETUP_VER=$SETUP_VER" --prefix="KIRA_SETUP_VER=" --path=$ETC_PROFILE --append-if-found-not=True

        touch $KIRA_SETUP_ESSSENTIALS
    else
        echo "INFO: Essentials were already installed: $(git --version), Curl, Wget..."
    fi

    CDHelper text lineswap --insert="SILENT_MODE=$SILENT_MODE" --prefix="SILENT_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="DEBUG_MODE=$DEBUG_MODE" --prefix="DEBUG_MODE=" --path=$ETC_PROFILE --append-if-found-not=True
    #########################################
    # END Installing Essentials
    #########################################

    echo "INFO: Updating kira Repository..."
    rm -rfv $KIRA_INFRA
    mkdir -p $KIRA_INFRA
    git clone --branch $INFRA_BRANCH $INFRA_REPO $KIRA_INFRA
    cd $KIRA_INFRA
    git describe --all --always
    chmod -R 777 $KIRA_INFRA

    # update old processes
    rm -r -f $KIRA_MANAGER
    cp -r $KIRA_WORKSTATION $KIRA_MANAGER
    chmod -R 555 $KIRA_MANAGER

    cd /kira
    echo "INFO: ReStarting init script to launch setup menu..."
    source $KIRA_WORKSTATION/init.sh "True" "$START_TIME_INIT" "$DEBUG_MODE" "$INTERACTIVE"
    echo "INFO: Init script restart finished."
    exit 0
else
    echo "INFO: Skipping init update..."
fi

CDHelper text lineswap --insert="KIRA_DUMP=$KIRA_DUMP" --prefix="KIRA_DUMP=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KIRA_PROGRESS=$KIRA_PROGRESS" --prefix="KIRA_PROGRESS=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KIRA_USER=$KIRA_USER" --prefix="KIRA_USER=" --path=$ETC_PROFILE --append-if-found-not=True

CDHelper text lineswap --insert="INFRA_BRANCH=$INFRA_BRANCH" --prefix="INFRA_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KMS_BRANCH=$KMS_BRANCH" --prefix="KMS_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True

CDHelper text lineswap --insert="INFRA_REPO=$INFRA_REPO" --prefix="INFRA_REPO=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SEKAI_REPO=$SEKAI_REPO" --prefix="SEKAI_REPO=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FRONTEND_REPO=$FRONTEND_REPO" --prefix="FRONTEND_REPO=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="KMS_REPO=$KMS_REPO" --prefix="KMS_REPO=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_REPO=$INTERX_REPO" --prefix="INTERX_REPO=" --path=$ETC_PROFILE --append-if-found-not=True

CDHelper text lineswap --insert="KIRA_STOP=$KIRA_STOP" --prefix="KIRA_STOP=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="ETC_PROFILE=$ETC_PROFILE" --prefix="ETC_PROFILE=" --path=$ETC_PROFILE --append-if-found-not=True

cd /kira
echo "INFO: Launching setup menu..."
source $KIRA_WORKSTATION/menu.sh

echo "------------------------------------------------"
echo "| FINISHED: SETUP                              |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME_INIT)) seconds"
echo "------------------------------------------------"
exit 0