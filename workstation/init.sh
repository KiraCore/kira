#!/usr/bin/env bash
set -e

# Accepted arguments:
# --infra-src="<url>"                   // source of the KM package
# --image-src="<url>"                   // source of the base image (optional)
# --init-mode="interactive/upgrade"     // initalization mode

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

# Used To Initialize essential dependencies, MUST be iterated if essentials require updating
BASE_IMAGE_VERSION="v0.13.0"
TOOLS_VERSION="v0.3.0"
COSIGN_VERSION="v1.13.1"

set +x
echo -e  "\e[1;40m======================================================\e[0m"
echo -e  "\e[1;40m|               KIRA | Manager Init Script           |\e[0m"   
echo -e  "\e[1;40m|====================================================|\e[0m"
echo -e  "\e[1;40m|           KIRA USER: $KIRA_USER                     \e[0m"
echo -e  "\e[1;40m|       TOOLS VERSION: $TOOLS_VERSION                 \e[0m"
echo -e  "\e[1;40m|      COSIGN VERSION: $COSIGN_VERSION                \e[0m"
echo -e  "\e[1;40m|   BASE IMG. VERSION: $BASE_IMAGE_VERSION            \e[0m"
echo -e  "\e[1;40m======================================================\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@@@@&BG&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@B?^..^75B&@@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@##@@@&GJ!:   .~?P#@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@#GJ!::!YG&@@&#P?^.  .:!YG&@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@&B57^.      .^75B&@@&BY!^.  .^75B&@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@#J~.              :~JG#@@@#Y^     .~JB@@@@@@@@@@@@#@@\e[0m"
echo -e  "\e[1;40m@&BY7^.               .^7YJ~:     :~?P#@@@@@@@@#GJ!~#@\e[0m"
echo -e  "\e[1;40m@@@@@#GJ~:                    .^75B&@@@@@@@&B57^.  :#@\e[0m"
echo -e  "\e[1;40m@@@@@@@@&#P?^.            .:!YG&@@@@@@@&B5?^.      :#@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@&B57^.     :~JG#@@@@@@@@#PJ~:          :#@\e[0m"
echo -e  "\e[1;40m@@@@@@@@&@@@@@@@#GJ!~?P#&@@@@@@@@GY!:.             :#@\e[0m"
echo -e  "\e[1;40m@@@@@@@#!75B&@@@@@@&&@@@@@@@@@@@#^                .!#@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.  :~JP#@@@@@@@@@@@@@@@@#:            .^75B&@@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.     .:!YG&@@@@@@@@@@@@#:        .^75B&@@&#@@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.   :.    .^75B&@@@@@@@@#:    .:!YG&@@@#GJ!~#@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.  :GGJ~      .~?P#@@@@@#:   .5#@@@&GY!:.  ^#@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.  :#@@#:        .7@@@@@#:   :B&B57^.  .^!YB@@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.  :#@@#:         !@@@@@#:   .!^.   :!JG#@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@B.  ^&@@#:         !@@@@@#:      .~?P#&@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@G.  ^&@@#:         !@@@@@#:  .^75B&@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@G.  ^&@@B.         !@@@@@#~!YB&@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@&57^~&@@B.         !@@@@@@&@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@#B@@@B.         !@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@#?~.       !@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@@&B57^.   !@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@@@@@@&GY!:7@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@@@@@@@@@@#B@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
echo -e  "\e[1;40m@@ KIRA - PUSHING THE LIMITS OF TRUSTLESS COMPUTING @@\e[0m"
echo -e  "\e[1;40m@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\e[0m"
sleep 3
echo -n ""
set -x
# this is essential to remove any inpropper output redirections to /dev/null while silencing output
rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :

ARCH=$(uname -m) && ( [[ "${ARCH,,}" == *"arm"* ]] || [[ "${ARCH,,}" == *"aarch"* ]] ) && ARCH="arm64" || ARCH="amd64"
PLATFORM=$(uname) && PLATFORM=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')

COSIGN_NOT_INSTALLED=$(cosign version || echo "true")
KEYS_DIR="/usr/keys"
KIRA_COSIGN_PUB="$KEYS_DIR/kira-cosign.pub"

if [ "$COSIGN_NOT_INSTALLED" == "true" ] ; then
    echo "INFO: Installing cosign"
    FILE_NAME=$(echo "cosign-${PLATFORM}-${ARCH}" | tr '[:upper:]' '[:lower:]')
    wget https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/$FILE_NAME && chmod +x -v ./$FILE_NAME
    FILE_HASH=$(sha256sum ./$FILE_NAME | awk '{ print $1 }' | xargs || echo -n "")
    COSIGN_HASH_ARM="a50651a67b42714d6f1a66eb6773bf214dacae321f04323c0885f6a433051f95"
    COSIGN_HASH_AMD="a7a79a52c7747e2c21554cad4600e6c7130c0429017dd258f9c558d957fa9090"
    if [ "$FILE_HASH" != "$COSIGN_HASH_ARM" ] && [ "$FILE_HASH" != "$COSIGN_HASH_AMD" ] ; then
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

# Ensure variables are stored and no modification takes place after loading envs
./$FILE_NAME globSet KIRA_USER "$KIRA_USER"
./$FILE_NAME globSet TOOLS_VERSION "$TOOLS_VERSION"
./$FILE_NAME globSet COSIGN_VERSION "$COSIGN_VERSION"
./$FILE_NAME globSet KIRA_COSIGN_PUB "$KIRA_COSIGN_PUB"

. /etc/profile
echoInfo "INFO: Installed bash-utils $(bashUtilsVersion)"

#######################################################################################
echoInfo "INFO: Processing input arguments..."
INFRA_SRC="" && infra_src="" && arg1="$1" && [ -z "$arg1" ] && arg1="--arg1=null"
IMAGE_SRC="" && image_src="" && arg2="$2" && [ -z "$arg2" ] && arg2="--arg2=null"
INIT_MODE="" && init_mode="" && arg3="$3" && [ -z "$arg3" ] && arg3="--arg3=null"
getArgs "$arg1" "$arg2" "$arg3"
[ -z "$INFRA_SRC" ] && INFRA_SRC="$infra_src"
[ -z "$IMAGE_SRC" ] && IMAGE_SRC="$image_src" && [ -z $IMAGE_SRC ] && IMAGE_SRC="$BASE_IMAGE_VERSION"
[ -z "$INIT_MODE" ] && INIT_MODE="$init_mode" && [ -z $INIT_MODE ] && INIT_MODE="interactive"

($(isVersion "$INFRA_SRC")) && INFRA_SRC="https://github.com/KiraCore/kira/releases/download/$INFRA_SRC/kira.zip"
($(isCID "$INFRA_SRC")) && INFRA_SRC="https://ipfs.kira.network/ipfs/$INFRA_SRC/kira.zip"
(! $(urlExists "$INFRA_SRC")) && echoErr "ERROR: Infrastructure source URL '$INFRA_SRC' does NOT contain source files!" && exit 1

($(isVersion "$IMAGE_SRC")) && IMAGE_SRC="ghcr.io/kiracore/docker/kira-base:$IMAGE_SRC"
(! $(urlExists "$IMAGE_SRC")) && echoErr "ERROR: Base Image URL '$IMAGE_SRC' does NOT contain image files!" && exit 1
#######################################################################################

if [ $INIT_MODE == "interactive" ] ; then
    systemctl stop kiraup || echo "WARNING: KIRA Update service could NOT be stopped, service might not exist yet!"
    systemctl stop kiraplan || echo "WARNING: KIRA Upgrade Plan service could NOT be stopped, service might not exist yet!"

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
fi

echoInfo "INFO: Veryfying kira base image integrity..."
cosign verify --key "$(globGet KIRA_COSIGN_PUB)" $IMAGE_SRC || \
 ( echoErr "ERROR: Base image integrity verification failed, retry will be attempted in 60 seconds..." && sleep 60 && cosign verify --key "$(globGet KIRA_COSIGN_PUB)" $IMAGE_SRC )

echoInfo "INFO: Setting up essential ENV variables & constants..."
globSet BASE_IMAGE_SRC "$IMAGE_SRC"

setGlobEnv INFRA_SRC "$INFRA_SRC"
setGlobEnv INIT_MODE "$INIT_MODE"
# NOTE: Glob envs can be loaded only AFTER init provided variabes are set
loadGlobEnvs

set +x
echoWarn  "======================================================"
echoWarn  "|              KIRA | Manager Init Script            |"   
echoWarn  "|====================================================|"
echoWarn  "|          KIRA USER: $(globGet KIRA_USER)"
echoWarn  "|          INIT MODE: $INIT_MODE"
echoWarn  "|       INFRA SOURCE: $INFRA_SRC"
echoWarn  "|   BASE IMG. SOURCE: $IMAGE_SRC"
echoWarn  "|      TOOLS VERSION: $(globGet TOOLS_VERSION)"
echoWarn  "|     COSIGN VERSION: $(globGet COSIGN_VERSION)"
echoWarn  "======================================================"
sleep 3
echo -n ""
set -x

KIRA_HOME="/home/$(globGet KIRA_USER)"      && setGlobEnv KIRA_HOME "$KIRA_HOME"
KIRA_LOGS="$KIRA_HOME/logs"                 && setGlobEnv KIRA_LOGS "$KIRA_LOGS"
KIRA_DUMP="$KIRA_HOME/dump"                 && setGlobEnv KIRA_DUMP "$KIRA_DUMP"
KIRA_SNAP="$KIRA_HOME/snap"                 && setGlobEnv KIRA_SNAP "$KIRA_SNAP" 
KIRA_SCAN="$KIRA_HOME/kirascan"             && setGlobEnv KIRA_SCAN "$KIRA_SCAN"
KIRA_SECRETS="$KIRA_HOME/.secrets"          && setGlobEnv KIRA_SECRETS "$KIRA_SECRETS"
KIRA_CONFIGS="$KIRA_HOME/.kira"             && setGlobEnv KIRA_CONFIGS "$KIRA_CONFIGS"

PUBLIC_PEERS="$KIRA_CONFIGS/public_peers"   && setGlobEnv PUBLIC_PEERS "$KIRA_CONFIGS/public_peers"
PUBLIC_SEEDS="$KIRA_CONFIGS/public_seeds"   && setGlobEnv PUBLIC_SEEDS "$KIRA_CONFIGS/public_seeds"

#KIRA_REPOS="/kira/repos"            && setGlobEnv KIRA_REPOS "$KIRA_REPOS"
#KIRA_INFRA="$KIRA_REPOS/kira"       && setGlobEnv KIRA_INFRA "$KIRA_INFRA"
#KIRA_SEKAI="$KIRA_REPOS/sekai"      && setGlobEnv KIRA_SEKAI "$KIRA_SEKAI"
#KIRA_INTERX="$KIRA_REPOS/interx"    && setGlobEnv KIRA_INTERX "$KIRA_INTERX"
KIRA_INFRA="/kira/repos/kira"       && setGlobEnv KIRA_INFRA "$KIRA_INFRA"

KIRA_BIN="/kira/bin"                && setGlobEnv KIRA_BIN "$KIRA_BIN"
KIRA_SETUP="/kira/setup"            && setGlobEnv KIRA_SETUP "$KIRA_SETUP"
KIRA_MANAGER="/kira/manager"        && setGlobEnv KIRA_MANAGER "$KIRA_MANAGER"

KIRA_COMMON="${KIRA_INFRA}/common"              && setGlobEnv KIRA_COMMON "$KIRA_COMMON"
KIRA_WORKSTATION="${KIRA_INFRA}/workstation"    && setGlobEnv KIRA_WORKSTATION "$KIRA_WORKSTATION"

SEKAID_HOME="/root/.sekai"          && setGlobEnv SEKAID_HOME "$SEKAID_HOME"
INTERXD_HOME="/root/.interx"        && setGlobEnv INTERXD_HOME "$INTERXD_HOME"

DOCKER_HOME="/docker/shared/home"   && setGlobEnv DOCKER_HOME "$DOCKER_HOME"
DOCKER_COMMON="/docker/shared/common"   && setGlobEnv DOCKER_COMMON "$DOCKER_COMMON"
# read only common directory
DOCKER_COMMON_RO="/docker/shared/common_ro"             && setGlobEnv DOCKER_COMMON_RO "$DOCKER_COMMON_RO"
GLOBAL_COMMON_RO="/docker/shared/common_ro/kiraglob"    && setGlobEnv GLOBAL_COMMON_RO "$GLOBAL_COMMON_RO"
LOCAL_GENESIS_PATH="$DOCKER_COMMON_RO/genesis.json"     && setGlobEnv LOCAL_GENESIS_PATH "$LOCAL_GENESIS_PATH"

rm -rfv $KIRA_DUMP
mkdir -p "$KIRA_LOGS" "$KIRA_DUMP" "$KIRA_SNAP" "$KIRA_CONFIGS" "$KIRA_SECRETS" "/var/kiraglob"
mkdir -p "$KIRA_DUMP/INFRA/manager" $KIRA_INFRA $KIRA_SEKAI $KIRA_INTERX $KIRA_SETUP $KIRA_MANAGER $DOCKER_COMMON $DOCKER_COMMON_RO $GLOBAL_COMMON_RO

echoInfo "INFO: Installing Essential Packages..."
rm -fv /var/lib/apt/lists/lock || echo "WARINING: Failed to remove APT lock"
loadGlobEnvs

apt-get update -y --fix-missing
apt-get install -y --fix-missing --allow-downgrades --allow-remove-essential --allow-change-held-packages \
    software-properties-common apt-transport-https ca-certificates gnupg curl wget git build-essential htop ccze sysstat \
    nghttp2 libnghttp2-dev libssl-dev fakeroot dpkg-dev libcurl4-openssl-dev net-tools jq aptitude zip unzip p7zip-full \
    python3 python3-pip tar md5deep linux-tools-common linux-tools-generic pm-utils autoconf libtool fuse nasm net-tools \
    perl libdata-validate-ip-perl libio-socket-ssl-perl libjson-perl bc dnsutils psmisc netcat nmap parallel

pip3 install ECPy

echoInfo "INFO: Updating kira Repository..."
safeWget /tmp/kira.zip "$INFRA_SRC" "$(globGet KIRA_COSIGN_PUB)"
rm -rfv "$KIRA_INFRA" && mkdir -p "$KIRA_INFRA"
unzip /tmp/kira.zip -d $KIRA_INFRA
chmod -R 555 $KIRA_INFRA

# update old processes
rm -rfv $KIRA_MANAGER && mkdir -p $KIRA_MANAGER
cp -rfv "$KIRA_WORKSTATION/." $KIRA_MANAGER
chmod -R 555 $KIRA_MANAGER

KIRA_SETUP_VER=$($KIRA_INFRA/scripts/version.sh || echo "")
[ -z "KIRA_SETUP_VER" ] && echoErr "ERROR: Invalid setup release version!" && exit 1
setGlobEnv KIRA_SETUP_VER "$KIRA_SETUP_VER"

echoInfo "INFO: Startting cleanup..."
timeout 60 apt-get autoclean -y || echoWarn "WARNING: autoclean failed"
timeout 60 apt-get clean -y || echoWarn "WARNING: clean failed"
timeout 60 apt-get autoremove -y || echoWarn "WARNING: autoremove failed"
timeout 60 journalctl --vacuum-time=3d || echoWarn "WARNING: journalctl vacuum failed"

$KIRA_MANAGER/setup/tools.sh

if [ $INIT_MODE == "interactive" ] ; then
    set +x
    echoInfo "INFO: Your host environment was initialized"
    echoWarn "TERMS & CONDITIONS: Make absolutely sure that you are NOT running this script on your primary PC operating system, it can cause irreversible data loss and change of firewall rules which might make your system vulnerable to various security threats or entirely lock you out of the system. By proceeding you take full responsibility for your own actions and accept that you continue on your own risk. You also acknowledge that malfunction of any software you run might potentially cause irreversible loss of assets due to unforeseen issues and circumstances including but not limited to hardware and/or software faults and/or vulnerabilities."
    echoNErr "Press any key to accept terms & continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
    echoInfo "INFO: Launching setup menu..."
    set -x
    source $KIRA_MANAGER/menu/menu.sh "true"
elif [ $INIT_MODE == "upgrade" ] ; then
    echoInfo "INFO: Starting upgrade & restarting update daemon..."
    globDel "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "CONTAINERS_UPDATED_$KIRA_SETUP_VER"
    rm -fv "$(globGet UPDATE_TOOLS_LOG)" "$(globGet UPDATE_CLEANUP_LOG)" "$(globGet UPDATE_CONTAINERS_LOG)"
    globSet NEW_NETWORK "false"
    systemctl daemon-reload
    timeout 60 systemctl restart kiraup
else
    echoErr "ERROR: Unknown init-mode flag '$INIT_MODE'"
    exit 1
fi

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: INIT                               |"
echoInfo "------------------------------------------------"
set -x
