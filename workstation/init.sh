#!/usr/bin/env bash
set -e

INFRA_BRANCH="${1,,}"
SKIP_UPDATE="$2"
START_TIME_INIT=$3

[ ! -z "$SUDO_USER" ] && KIRA_USER=$SUDO_USER
[ -z "$KIRA_USER" ] && KIRA_USER=$USER
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="false"

[ "$KIRA_USER" == "root" ] && KIRA_USER=$(logname)
if [ "$KIRA_USER" == "root" ]; then
    echo "ERROR: You must login as non root user to your machine!"
    exit 1
fi

if [ "${USER,,}" != root ]; then
    echo "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

# Used To Initialize essential dependencies, MUST be iterated if essentials require updating
KIRA_MANAGER_VERSION="v0.0.1"
KIRA_BASE_VERSION="v0.10.3"
TOOLS_VERSION="v0.1.5"
COSIGN_VERSION="v1.7.2"
CDHELPER_VERSION="v0.6.51"
INFRA_REPO="https://github.com/KiraCore/kira"
UTILS_VERSION=$(utilsVersion 2> /dev/null || echo "")

set +x
echo "------------------------------------------------"
echo "|      STARTED: INIT"
echo "|-----------------------------------------------"
echo "|       SKIP UPDATE: $SKIP_UPDATE"
echo "|        START TIME: $START_TIME_INIT"
echo "|      INFRA BRANCH: $INFRA_BRANCH"
echo "|         KIRA USER: $KIRA_USER"
echo "|     TOOLS VERSION: $TOOLS_VERSION"
echo "|  CDHELPER VERSION: $CDHELPER_VERSION"
echo "| KIRA MNG. VERSION: $KIRA_MANAGER_VERSION"
echo "------------------------------------------------"
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

systemctl stop kiraup || echo "WARNING: KIRA Update service could NOT be stopped, service might not exist yet!"
systemctl stop kiraplan || echo "WARNING: KIRA Upgrade Plan service could NOT be stopped, service might not exist yet!"

echo -n ""
set -x
# this is essential to remove any inpropper output redirections to /dev/null while silencing output
rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :

ARCH=$(uname -m) && ( [[ "${ARCH,,}" == *"arm"* ]] || [[ "${ARCH,,}" == *"aarch"* ]] ) && ARCH="arm64" || ARCH="amd64"
PLATFORM=$(uname) && PLATFORM=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')

if [ "${ARCH}" == "arm64" ] ; then
    COSIGN_HASH="2448231e6bde13722aad7a17ac00789d187615a24c7f82739273ea589a42c94b"
else
    COSIGN_HASH="80f80f3ef5b9ded92aa39a9dd8e028f5b942a3b6964f24c47b35e7f6e4d18907"
fi

COSIGN_INSTALLED=$(isCommand cosign || echo "false")
KEYS_DIR="/usr/keys"
KIRA_COSIGN_PUB="$KEYS_DIR/kira-cosign.pub"

if [ "$COSIGN_INSTALLED" != "true" ] ; then
    echo "INFO: Installing cosign"
    FILE_NAME=$(echo "cosign-${PLATFORM}-${ARCH}" | tr '[:upper:]' '[:lower:]')
    wget https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/$FILE_NAME && chmod +x -v ./$FILE_NAME
    FILE_HASH=$(sha256sum ./$FILE_NAME | awk '{ print $1 }' | xargs || echo -n "")
    if [ "$FILE_HASH" != "$COSIGN_HASH" ] ; then
        echoErr "ERROR: Failed to download cosign tool, expected checksum to be '$COSIGN_HASH', but got '$FILE_HASH'"
        exit 1
    fi

    mv -fv ./$FILE_NAME /usr/local/bin/cosign
    cosign version
    
    mkdir -p $KEYS_DIR
    cat > $KIRA_COSIGN_PUB << EOL
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE/IrzBQYeMwvKa44/DF/HB7XDpnE+
f+mU9F/Qbfq25bBWV2+NlYMJv3KvKHNtu3Jknt6yizZjUV4b8WGfKBzFYw==
-----END PUBLIC KEY-----
EOL

fi

FILE_NAME="bash-utils.sh" && \
 wget "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/${FILE_NAME}" -O ./$FILE_NAME && \
 wget "https://github.com/KiraCore/tools/releases/download/$TOOLS_VERSION/${FILE_NAME}.sig" -O ./${FILE_NAME}.sig && \
 cosign verify-blob --key="$KIRA_COSIGN_PUB" --signature=./${FILE_NAME}.sig ./$FILE_NAME && \
 chmod -v 755 ./$FILE_NAME && ./$FILE_NAME bashUtilsSetup "/var/kiraglob" 

source $FILE_NAME
echoInfo "INFO: Installed bash-utils $(bash-utils bashUtilsVersion)"

set +x
if [[ $(getCpuCores) -lt 2 ]] ; then
    echo -en "\e[31;1mERROR: KIRA Manager requires at lest 2 CPU cores but your machine has only $(getCpuCores)\e[0m"
    echo "INFO: Recommended CPU is 4 cores"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
fi

if [[ $(getRamTotal) -lt 3145728 ]] ; then
    echo -en "\e[31;1mERROR: KIRA Manager requires at lest 4 GB RAM but your machine has only $(getRamTotal) kB\e[0m"
    echo "INFO: Recommended RAM is 8GB"
    echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""
fi
set -x

echoInfo "INFO: Veryfying kira base image integrity..."
cosign verify --key $KIRA_COSIGN_PUB ghcr.io/kiracore/docker/kira-base:$KIRA_BASE_VERSION

setGlobEnv KIRA_BASE_VERSION "$KIRA_BASE_VERSION"
setGlobEnv TOOLS_VERSION "$TOOLS_VERSION"
setGlobEnv COSIGN_VERSION "$COSIGN_VERSION"
setGlobEnv CDHELPER_VERSION "$CDHELPER_VERSION"
setGlobEnv KIRA_USER "$KIRA_USER"
setGlobEnv INFRA_BRANCH "$INFRA_BRANCH"
setGlobEnv INFRA_REPO "$INFRA_REPO"
setGlobEnv KIRA_COSIGN_PUB "$KIRA_COSIGN_PUB"

echoInfo "INFO: Setting up essential ENV variables & constant..."

[ -z "$INFRA_BRANCH" ] && echoErr "ERROR: Infra branch was undefined!" && exit 1
[ -z "$START_TIME_INIT" ] && START_TIME_INIT="$(date -u +%s)"

# NOTE: Glob envs can be loaded only AFTER init provided variabes are set
loadGlobEnvs

KIRA_HOME="/home/$KIRA_USER"                && setGlobEnv KIRA_HOME "$KIRA_HOME"
KIRA_LOGS="$KIRA_HOME/logs"                 && setGlobEnv KIRA_LOGS "$KIRA_LOGS"
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

KIRA_BIN="/kira/bin"                && setGlobEnv KIRA_BIN "$KIRA_BIN"
KIRA_SETUP="/kira/setup"            && setGlobEnv KIRA_SETUP "$KIRA_SETUP"
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
mkdir -p "$KIRA_LOGS" "$KIRA_DUMP" "$KIRA_SNAP" "$KIRA_CONFIGS" "$KIRA_SECRETS" "/var/kiraglob"
mkdir -p "$KIRA_DUMP/INFRA/manager" $KIRA_INFRA $KIRA_SEKAI $KIRA_INTERX $KIRA_SETUP $KIRA_MANAGER $DOCKER_COMMON $DOCKER_COMMON_RO $GLOBAL_COMMON_RO

# # All branches should have the same name across all repos to be considered compatible
# if [[ $INFRA_BRANCH == mainnet* ]] || [[ $INFRA_BRANCH == testnet* ]] ; then
#     DEFAULT_BRANCH="$INFRA_BRANCH"
#     SEKAI_BRANCH="$DEFAULT_BRANCH"
#     INTERX_BRANCH="$DEFAULT_BRANCH"
# else
#     DEFAULT_BRANCH="master"
#     [ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH="$DEFAULT_BRANCH"
#     [ -z "$INTERX_BRANCH" ] && INTERX_BRANCH="$DEFAULT_BRANCH"
# fi
# setGlobEnv INFRA_BRANCH "$INFRA_BRANCH"
# setGlobEnv SEKAI_BRANCH "$SEKAI_BRANCH"
# setGlobEnv INTERX_BRANCH "$INTERX_BRANCH"
# 
#INFRA_REPO="https://github.com/KiraCore/kira" && setGlobEnv INFRA_REPO "$INFRA_REPO"
# SEKAI_REPO="https://github.com/KiraCore/sekai" && setGlobEnv SEKAI_REPO "$SEKAI_REPO"
# INTERX_REPO="https://github.com/KiraCore/sekai" && setGlobEnv INTERX_REPO "$INTERX_REPO"

echoInfo "INFO: Installing Essential Packages..."
rm -fv /var/lib/apt/lists/lock || echo "WARINING: Failed to remove APT lock"
loadGlobEnvs

apt-get update -y --fix-missing
apt-get install -y --fix-missing --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common apt-transport-https ca-certificates gnupg curl wget git build-essential htop ccze sysstat \
    nghttp2 libnghttp2-dev libssl-dev fakeroot dpkg-dev libcurl4-openssl-dev net-tools jq aptitude zip unzip p7zip-full \
    python python3 python3-pip tar md5deep linux-tools-common linux-tools-generic pm-utils autoconf libtool fuse nasm net-tools \
    perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl

pip3 install ECPy

apt update -y
apt install -y bc dnsutils psmisc netcat nmap parallel default-jre default-jdk 

ln -s /usr/bin/git /bin/git || echoWarn "WARNING: Git symlink already exists"
git config --add --global core.autocrlf input || echoWarn "WARNING: Failed to set global autocrlf"
git config --unset --global core.filemode || echoWarn "WARNING: Failed to unset global filemode"
git config --add --global core.filemode false || echoWarn "WARNING: Failed to set global filemode"
git config --add --global pager.branch false || echoWarn "WARNING: Failed to disable branch pager"
git config --add --global http.sslVersion "tlsv1.2" || echoWarn "WARNING: Failed to set ssl version"

if [ "${SKIP_UPDATE,,}" != "true" ]; then
    echoInfo "INFO: Updating kira Repository..."
    rm -rfv "$KIRA_INFRA" "$KIRA_MANAGER"
    mkdir -p "$KIRA_INFRA" "$KIRA_MANAGER"

    git clone --branch $INFRA_BRANCH $INFRA_REPO $KIRA_INFRA
    cd $KIRA_INFRA
    git describe --all --always
    chmod -R 555 $KIRA_INFRA

    # update old processes
    cp -rfv "$KIRA_WORKSTATION/." $KIRA_MANAGER
    chmod -R 555 $KIRA_MANAGER

    echoInfo "INFO: ReStarting init script to launch setup menu..."
    source $KIRA_MANAGER/init.sh "$INFRA_BRANCH" "true" "$START_TIME_INIT"
    echoInfo "INFO: Init script restart finished."
    exit 0
fi

KIRA_SETUP_VER=$(cat $KIRA_INFRA/version || echo "")
[ -z "KIRA_SETUP_VER" ] && echo -en "\e[31;1mERROR: Invalid setup release version!\e[0m" && exit 1
setGlobEnv KIRA_SETUP_VER "$KIRA_SETUP_VER"

echo "INFO: Startting cleanup..."
apt-get autoclean -y || echo "WARNING: autoclean failed"
apt-get clean -y || echo "WARNING: clean failed"
apt-get autoremove -y || echo "WARNING: autoremove failed"
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
