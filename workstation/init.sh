#!/usr/bin/env bash
set +e && chmod 555 /etc/profile && source /etc/profile &>/dev/null && set -e

INFRA_BRANCH="${1,,}"
SKIP_UPDATE=$2
START_TIME_INIT=$3

[ ! -z "$SUDO_USER" ] && KIRA_USER=$SUDO_USER
[ -z "$KIRA_USER" ] && KIRA_USER=$USER

[ "$KIRA_USER" == "root" ] && KIRA_USER=$(logname)
if [ "$KIRA_USER" == "root" ]; then
    echo "ERROR: You must login as non root user to your machine!"
    exit 1
fi

if [ "${USER,,}" != root ]; then
    echo "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")

if [[ $CPU_CORES -lt 2 ]] ; then
    echo -en "\e[31;1mERROR: KIRA Manager requires at lest 2 CPU cores but your machine has only $CPU_CORES\e[0m"
    echo "INFO: Recommended CPU is 4 cores"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
fi

if [[ $RAM_MEMORY -lt 3145728 ]] ; then
    echo -en "\e[31;1mERROR: KIRA Manager requires at lest 4 GB RAM but your machine has only $RAM_MEMORY kB\e[0m"
    echo "INFO: Recommended RAM is 8GB"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
fi

# Used To Initialize essential dependencies, MUST be iterated if essentials require updating
CDHELPER_VERSION="v0.6.51"
UTILS_VERSION=$(utilsVersion 2> /dev/null || echo "")
ARCHITECTURE=$(uname -m)

set +x
echo "------------------------------------------------"
echo "|      STARTED: INIT"
echo "|-----------------------------------------------"
echo "|  SKIP UPDATE: $SKIP_UPDATE"
echo "|   START TIME: $START_TIME_INIT"
echo "| INFRA BRANCH: $INFRA_BRANCH"
echo "|    KIRA USER: $KIRA_USER"
echo "| ARCHITECTURE: $ARCHITECTURE"
echo "------------------------------------------------"
set -x

set +x
if [ -z "$SKIP_UPDATE" ]; then
    echo -e  "\e[35;1mMMMMMMMMMMMWX0kdloxOKNWMMMMMMMMMMMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMWNKOxlc::::::cok0XWWMMMMMMMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMWX0kdlc::::::::::::clxkOKNMMMMMMMMMMWKkk0NWMMMMM"
    echo             "MMMNkoc:::::::::::::::::::::cok0NWMMMMMMWKxlcld0NMMM"
    echo             "MMW0l:cllc:::::::::::::::::::::coKWMMMMMMMWKo:;:xNMM"
    echo             "MMWOlcxXNKOdlc::::::::::::::::::l0WMMMMMWNKxc;;;oXMM"
    echo             "MMW0olOWMMMWX0koc::::::::::::ldOXWMMMWXOxl:;;;;;oXMM"
    echo             "MMMWXKNMMMMMMMWNKOdl::::codk0NWMMWNKkdc:;;;;;;;;oXMM"
    echo             "MMMMMMMMMMMMMMMMMMWX0kkOKNWMMMWX0xl:;;;;;;;;;;;;oXMM"
    echo             "MMMMMMMMMMMWXOkOKNMMMMMMMMMMMW0l:;;;;;;;;;;;;;;;oXMM"
    echo             "MMMMMMMMMMMXo:::cox0XWMMMMMMMNx:;;;;;;;;;;;;;;;;oXMM"
    echo             "MMMMMMMMMMMKl:::::::ldOXWMMMMNx:;;;;;;;;;;;;;;co0WMM"
    echo             "MMMMMMMMMMMKl::::;;;;;:ckWMMMNx:;;;;;;;;;;:ldOKNMMMM"
    echo             "MMMMMMMMMMMKl;;;;;;;;;;;dXMMMNx:;;;;;;;:ox0XWMMMMMMM"
    echo             "MMMMMMMMMMMKl;;;;;;;;;;;dXMMMWk:;;;:cdkKNMMMMMMMMMMM"
    echo             "MMMMMMMMMMMKl;;;;;;;;;;;dXMMMMXkoox0XWMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMKl;;;;;;;;;;;dXMMMMMWWWMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMKl;;;;;;;;;;;dXMMMMMMMMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMKo;;;;;;;;;;;dXMMMMMMMMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMWKxl:;;;;;;;;oXMMMWNWMMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMMMWNKkdc;;;;;:dOOkdlkNMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMMMMMMMWXOxl:;;;;;cokKWMMMMMMMMMMMMMMMMMMM"
    echo             "MMMMMMMMMMMMMMMMMMMMWN0kdxxOKWMMMMMMMMMMMMMMMMMMMMMM"
    echo             "MMM              KIRA NETWORK SETUP              MMM"
    echo -e          "MMMMMMMMMMMMMMMMMMMMMMMMWWMMMMMMMMMMMMMMMMMMMMMMMMMM\e[0m\c\n"
    sleep 3
else
    echoInfo "INFO: Initalizing setup script..."
fi

systemctl stop kiraup || echo "WARNING: KIRA Update service could NOT be stopped, service might not exist yet!"
systemctl stop kiraplan || echo "WARNING: KIRA Upgrade Plan service could NOT be stopped, service might not exist yet!"

echo -n ""
set -x
rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :

# Installing utils is essential to simplify the setup steps
if [[ $(versionToNumber "$UTILS_VERSION" || echo "0") -ge $(versionToNumber "v0.0.15" || echo "1") ]] ; then
    echo "INFO: KIRA utils were NOT installed on the system, setting up..." && sleep 2
    KIRA_UTILS_BRANCH="v0.0.3" && cd /tmp && rm -fv ./i.sh && \
    wget https://raw.githubusercontent.com/KiraCore/tools/$KIRA_UTILS_BRANCH/bash-utils/install.sh -O ./i.sh && \
    chmod 555 ./i.sh && ./i.sh "$KIRA_UTILS_BRANCH" "/var/kiraglob" && . /etc/profile && loadGlobEnvs
else
    echoInfo "INFO: KIRA utils are up to date, latest version $UTILS_VERSION" && sleep 2
fi

echoInfo "INFO: Setting up essential ENV variables & constant..."

[ -z "$ETC_PROFILE" ] && ETC_PROFILE="/etc/profile" && setGlobEnv ETC_PROFILE "$ETC_PROFILE"

[ -z "$INFRA_BRANCH" ] && INFRA_BRANCH="master"
[ -z "$START_TIME_INIT" ] && START_TIME_INIT="$(date -u +%s)"
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="false"
[ -z "$DEFAULT_SSH_PORT" ] && DEFAULT_SSH_PORT="22" && setGlobEnv DEFAULT_SSH_PORT "$DEFAULT_SSH_PORT"

DEFAULT_P2P_PORT="26656"        && setGlobEnv DEFAULT_P2P_PORT "$DEFAULT_P2P_PORT"
DEFAULT_RPC_PORT="26657"        && setGlobEnv DEFAULT_RPC_PORT "$DEFAULT_RPC_PORT"
DEFAULT_PROMETHEUS_PORT="26660" && setGlobEnv DEFAULT_PROMETHEUS_PORT "$DEFAULT_PROMETHEUS_PORT"
DEFAULT_GRPC_PORT="9090"        && setGlobEnv DEFAULT_GRPC_PORT "$DEFAULT_GRPC_PORT"
DEFAULT_INTERX_PORT="11000"     && setGlobEnv DEFAULT_INTERX_PORT "$DEFAULT_INTERX_PORT"
        
KIRA_REGISTRY_PORT="5000"   && setGlobEnv KIRA_REGISTRY_PORT "$KIRA_REGISTRY_PORT"
KIRA_INTERX_PORT="11000"    && setGlobEnv KIRA_INTERX_PORT "$KIRA_INTERX_PORT"

KIRA_SEED_P2P_PORT="16656"              && setGlobEnv KIRA_SEED_P2P_PORT "$KIRA_SEED_P2P_PORT"
KIRA_SEED_RPC_PORT="16657"              && setGlobEnv KIRA_SEED_RPC_PORT "$KIRA_SEED_RPC_PORT"
KIRA_SEED_GRPC_PORT="19090"             && setGlobEnv KIRA_SEED_GRPC_PORT "$KIRA_SEED_GRPC_PORT"
KIRA_SEED_PROMETHEUS_PORT="16660"       && setGlobEnv KIRA_SEED_PROMETHEUS_PORT "$KIRA_SEED_PROMETHEUS_PORT"

KIRA_SENTRY_RPC_PORT="26657"            && setGlobEnv KIRA_SENTRY_RPC_PORT "$KIRA_SENTRY_RPC_PORT"
KIRA_SENTRY_P2P_PORT="26656"            && setGlobEnv KIRA_SENTRY_P2P_PORT "$KIRA_SENTRY_P2P_PORT"
KIRA_SENTRY_GRPC_PORT="29090"           && setGlobEnv KIRA_SENTRY_GRPC_PORT "$KIRA_SENTRY_GRPC_PORT"
KIRA_SENTRY_PROMETHEUS_PORT="26660"     && setGlobEnv KIRA_SENTRY_PROMETHEUS_PORT "$KIRA_SENTRY_PROMETHEUS_PORT"

KIRA_VALIDATOR_P2P_PORT="36656"         && setGlobEnv KIRA_VALIDATOR_P2P_PORT "$KIRA_VALIDATOR_P2P_PORT"
KIRA_VALIDATOR_RPC_PORT="36657"         && setGlobEnv KIRA_VALIDATOR_RPC_PORT "$KIRA_VALIDATOR_RPC_PORT"
KIRA_VALIDATOR_GRPC_PORT="39090"        && setGlobEnv KIRA_VALIDATOR_GRPC_PORT "$KIRA_VALIDATOR_GRPC_PORT"
KIRA_VALIDATOR_PROMETHEUS_PORT="36660"  && setGlobEnv KIRA_VALIDATOR_PROMETHEUS_PORT "$KIRA_VALIDATOR_PROMETHEUS_PORT"

setGlobEnv KIRA_USER "$KIRA_USER"
KIRA_HOME="/home/$KIRA_USER"                && setGlobEnv KIRA_HOME "$KIRA_HOME"
KIRA_DUMP="$KIRA_HOME/dump"                 && setGlobEnv KIRA_DUMP "$KIRA_DUMP"
KIRA_SNAP="$KIRA_HOME/snap"                 && setGlobEnv KIRA_SNAP "$KIRA_SNAP" 
KIRA_SCAN="$KIRA_HOME/kirascan"             && setGlobEnv KIRA_SCAN "$KIRA_SCAN"
KIRA_SECRETS="$KIRA_HOME/.secrets"          && setGlobEnv KIRA_SECRETS "$KIRA_SECRETS"
KIRA_CONFIGS="$KIRA_HOME/.kira"             && setGlobEnv KIRA_CONFIGS "$KIRA_CONFIGS"

PUBLIC_PEERS="$KIRA_CONFIGS/public_peers"   && setGlobEnv PUBLIC_PEERS "$KIRA_CONFIGS/public_peers"
PUBLIC_SEEDS="$KIRA_CONFIGS/public_seeds"   && setGlobEnv PUBLIC_SEEDS "$KIRA_CONFIGS/public_seeds"

KIRA_REPOS="/kira/repos"            && setGlobEnv KIRA_REPOS "$KIRA_REPOS"
KIRA_INFRA="$KIRA_REPOS/kira"       && setGlobEnv KIRA_INFRA "$KIRA_INFRA"
KIRA_SEKAI="$KIRA_REPOS/sekai"      && setGlobEnv KIRA_SEKAI "$KIRA_SEKAI"
KIRA_INTERX="$KIRA_REPOS/interx"    && setGlobEnv KIRA_INTERX "$KIRA_INTERX"

KIRA_SETUP="/kira/setup"            && setGlobEnv KIRA_SETUP "$KIRA_SETUP"
KIRA_UPDATE="/kira/update"          && setGlobEnv KIRA_UPDATE "$KIRA_UPDATE"
KIRA_MANAGER="/kira/manager"        && setGlobEnv KIRA_MANAGER "$KIRA_MANAGER"

KIRA_SCRIPTS="${KIRA_INFRA}/common/scripts"     && setGlobEnv KIRA_SCRIPTS "$KIRA_SCRIPTS"
KIRA_WORKSTATION="${KIRA_INFRA}/workstation"    && setGlobEnv KIRA_WORKSTATION "$KIRA_WORKSTATION"

SEKAID_HOME="/root/.sekaid"             && setGlobEnv SEKAID_HOME "$SEKAID_HOME"

DOCKER_COMMON="/docker/shared/common"   && setGlobEnv DOCKER_COMMON "$DOCKER_COMMON"
# read only common directory
DOCKER_COMMON_RO="/docker/shared/common_ro"             && setGlobEnv DOCKER_COMMON_RO "$DOCKER_COMMON_RO"
GLOBAL_COMMON_RO="/docker/shared/common_ro/kiraglob"    && setGlobEnv GLOBAL_COMMON_RO "$GLOBAL_COMMON_RO"
LOCAL_GENESIS_PATH="$DOCKER_COMMON_RO/genesis.json"     && setGlobEnv LOCAL_GENESIS_PATH "$LOCAL_GENESIS_PATH"

rm -rfv $KIRA_DUMP
mkdir -p "$KIRA_DUMP" "$KIRA_SNAP" "$KIRA_CONFIGS" "$KIRA_SECRETS" "/var/kiraglob"
mkdir -p "$KIRA_DUMP/INFRA/manager" $KIRA_INFRA $KIRA_SEKAI $KIRA_INTERX $KIRA_SETUP $KIRA_MANAGER $DOCKER_COMMON $DOCKER_COMMON_RO $GLOBAL_COMMON_RO

# All branches should have the same name across all repos to be considered compatible
if [[ $INFRA_BRANCH == mainnet* ]] || [[ $INFRA_BRANCH == testnet* ]] ; then
    DEFAULT_BRANCH="$INFRA_BRANCH"
    SEKAI_BRANCH="$DEFAULT_BRANCH"
    INTERX_BRANCH="$DEFAULT_BRANCH"
else
    DEFAULT_BRANCH="master"
    [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH="$DEFAULT_BRANCH"
    [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH="$DEFAULT_BRANCH"
fi

setGlobEnv INFRA_BRANCH "$INFRA_BRANCH"
setGlobEnv SEKAI_BRANCH "$SEKAI_BRANCH"
setGlobEnv INTERX_BRANCH "$INTERX_BRANCH"

INFRA_REPO="https://github.com/KiraCore/kira" && setGlobEnv INFRA_REPO "$INFRA_REPO"
SEKAI_REPO="https://github.com/KiraCore/sekai" && setGlobEnv SEKAI_REPO "$SEKAI_REPO"
INTERX_REPO="https://github.com/KiraCore/sekai" && setGlobEnv INTERX_REPO "$INTERX_REPO"

CDHELPER_VERSION_OLD=$(CDHelper version --silent=true 2> /dev/null || echo "")

if [ "$CDHELPER_VERSION_OLD" != "$CDHELPER_VERSION" ] ; then
    echoInfo "INFO: Installing CDHelper '$CDHELPER_VERSION_OLD' -> '$CDHELPER_VERSION'"
    cd /tmp

    if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
        CDHELPER_ARCH="arm64"
        EXPECTED_HASH="c2e40c7143f4097c59676f037ac6eaec68761d965bd958889299ab32f1bed6b3"
    else
        CDHELPER_ARCH="x64"
        EXPECTED_HASH="082e05210f93036e0008658b6c6bd37ab055bac919865015124a0d72e18a45b7"
    fi

    FILE_HASH=$(sha256sum ./CDHelper-linux-$CDHELPER_ARCH.zip | awk '{ print $1 }' || echo -n "")

    if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
        rm -f -v ./CDHelper-linux-$CDHELPER_ARCH.zip
        wget "https://github.com/asmodat/CDHelper/releases/download/$CDHELPER_VERSION/CDHelper-linux-$CDHELPER_ARCH.zip"
        FILE_HASH=$(sha256sum ./CDHelper-linux-$CDHELPER_ARCH.zip | awk '{ print $1 }')

        if [ "$FILE_HASH" != "$EXPECTED_HASH" ]; then
            set +x
            echo -e "\nDANGER: Failed to check integrity hash of the CDHelper tool !!!\nERROR: Expected hash: $EXPECTED_HASH, but got $FILE_HASH\n"
            SELECT="" && while [ "${SELECT,,}" != "x" ] && [ "${SELECT,,}" != "c" ] ; do echo -en "\e[31;1mPress e[X]it or [C]ontinue to disregard the issue\e[0m\c" && read -d'' -s -n1 ACCEPT && echo ""; done
            [ "${SELECT,,}" == "x" ] && exit
            echo "DANGER: You decided to disregard a potential vulnerability !!!"
            echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
            set -x
        fi
    else
        echo "INFO: CDHelper tool was already downloaded"
    fi

    INSTALL_DIR="/usr/local/bin/CDHelper"
    rm -rfv $INSTALL_DIR
    mkdir -pv $INSTALL_DIR
    unzip CDHelper-linux-$CDHELPER_ARCH.zip -d $INSTALL_DIR
    chmod -R -v 555 $INSTALL_DIR

    ls -l /bin/CDHelper || echo "Symlink not found"
    rm -fv /bin/CDHelper || echo "Removing old symlink"
    ln -s $INSTALL_DIR/CDHelper /bin/CDHelper || echo "CDHelper symlink already exists"

    CDHelper version
else
    echoInfo "INFO: CDHelper $CDHELPER_VERSION_OLD is already installed"
fi

echoInfo "INFO: Installing Essential Packages..."
rm -fv /var/lib/apt/lists/lock || echo "WARINING: Failed to remove APT lock"
setGlobEnv DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1
loadGlobEnvs

apt-get update -y
apt-get install -y --fix-missing --allow-unauthenticated --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common apt-transport-https ca-certificates gnupg curl wget git build-essential \
    nghttp2 libnghttp2-dev libssl-dev fakeroot dpkg-dev libcurl4-openssl-dev net-tools jq aptitude \
    zip unzip p7zip-full 
    
apt update -y
apt install -y bc dnsutils psmisc netcat nmap parallel

ln -s /usr/bin/git /bin/git || echoWarn "WARNING: Git symlink already exists"
git config --add --global core.autocrlf input || echoWarn "WARNING: Failed to set global autocrlf"
git config --unset --global core.filemode || echoWarn "WARNING: Failed to unset global filemode"
git config --add --global core.filemode false || echoWarn "WARNING: Failed to set global filemode"
git config --add --global pager.branch false || echoWarn "WARNING: Failed to disable branch pager"
git config --add --global http.sslVersion "tlsv1.2" || echoWarn "WARNING: Failed to set ssl version"

if [ "${SKIP_UPDATE,,}" != "true" ]; then
    echoInfo "INFO: Updating kira Repository..."
    rm -rfv $KIRA_INFRA
    mkdir -p $KIRA_INFRA
    git clone --branch $INFRA_BRANCH $INFRA_REPO $KIRA_INFRA
    cd $KIRA_INFRA
    git describe --all --always
    chmod -R 555 $KIRA_INFRA

    # update old processes
    rm -rfv $KIRA_MANAGER && mkdir -p "$KIRA_MANAGER"
    cp -rfv "$KIRA_WORKSTATION/." $KIRA_MANAGER
    chmod -R 555 $KIRA_MANAGER

    echoInfo "INFO: ReStarting init script to launch setup menu..."
    source $KIRA_MANAGER/init.sh "$INFRA_BRANCH" "True" "$START_TIME_INIT"
    echoInfo "INFO: Init script restart finished."
    exit 0
fi

KIRA_SETUP_VER=$(cat $KIRA_INFRA/version || echo "")
[ -z "KIRA_SETUP_VER" ] && echo -en "\e[31;1mERROR: Invalid setup release version!\e[0m" && exit 1
setGlobEnv KIRA_SETUP_VER "$KIRA_SETUP_VER"

echo "INFO: Startting cleanup..."
apt-get autoclean || echo "WARNING: autoclean failed"
apt-get clean || echo "WARNING: clean failed"
apt-get autoremove || echo "WARNING: autoremove failed"
journalctl --vacuum-time=3d || echo "WARNING: journalctl vacuum failed"

$KIRA_MANAGER/setup/tools.sh

set +x
echoInfo "INFO: Your host environment was initialized"
echo -e "\e[33;1mTERMS & CONDITIONS: Make absolutely sure that you are NOT running this script on your primary PC operating system, it can cause irreversible data loss and change of firewall rules which might make your system vulnerable to various security threats or entirely lock you out of the system. By proceeding you take full responsibility for your own actions and accept that you continue on your own risk. You also acknowledge that malfunction of any software you run might potentially cause irreversible loss of assets due to unforeseen issues and circumstances including but not limited to hardware and/or software faults and/or vulnerabilities.\e[0m"
echoNErr "Press any key to accept terms & continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
echoInfo "INFO: Launching setup menu..."
set -x
source $KIRA_MANAGER/menu.sh "true"

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: INIT                               |"
echoInfo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_INIT)) seconds"
echoInfo "------------------------------------------------"
set -x
exit 0
