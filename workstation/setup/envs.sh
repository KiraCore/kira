#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# exec >> "$KIRA_DUMP/setup.log" 2>&1 && tail "$KIRA_DUMP/setup.log"

BASHRC=~/.bashrc
ETC_PROFILE="/etc/profile"

CARGO_ENV="/home/$KIRA_USER/.cargo/env"

KIRA_STATE=/kira/state
KIRA_REGISTRY_PORT=5000
KIRA_REGISTRY_SUBNET="100.0.0.0/8"
KIRA_VALIDATOR_SUBNET="10.2.0.0/16"
KIRA_VALIDATOR_IP="10.2.0.2"
KIRA_SENTRY_SUBNET="10.3.0.0/16"
KIRA_SENTRY_IP="10.3.0.2"
KIRA_SERVICE_SUBNET="10.4.0.0/16"
KIRA_INTERX_IP="10.4.0.2"
KIRA_FRONTEND_IP="10.4.0.3"
KIRA_REGISTRY_IP="100.0.1.1"
KIRA_REGISTRY_NAME="registry.local"
KIRA_REGISTRY="$KIRA_REGISTRY_NAME:$KIRA_REGISTRY_PORT"

KIRA_IMG="$KIRA_INFRA/common/img"
KIRA_DOCKER="$KIRA_INFRA/docker"
KIRAMGR_SCRIPTS="$KIRA_MANAGER/scripts"

VALIDATOR_P2P_PORT="26656"
RPC_PROXY_PORT="10001"

HOSTS_PATH="/etc/hosts"
NGINX_SERVICED_PATH="/etc/systemd/system/nginx.service.d"
NGINX_CONFIG="/etc/nginx/nginx.conf"

RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"
DOTNET_ROOT="/usr/bin/dotnet"
SOURCES_LIST="/etc/apt/sources.list.d"
DOCKER_COMMON="/docker/shared/common"

DARTBIN="/usr/lib/dart/bin"
FLUTTERROOT="/usr/lib/flutter"
FLUTTERBIN="$FLUTTERROOT/bin"

BREWBIN="/home/$KIRA_USER/.linuxbrew/bin"
MANPATH="/home/$KIRA_USER/.linuxbrew/share/man:$MANPATH"
INFOPATH="/home/$KIRA_USER/.linuxbrew/share/info:$INFOPATH"

mkdir -p $KIRA_STATE
mkdir -p "/home/$KIRA_USER/.cargo"
mkdir -p "/home/$KIRA_USER/Desktop"
mkdir -p $SOURCES_LIST

SETUP_CHECK="$KIRA_SETUP/kira-env-v0.0.55"
if [ ! -f "$SETUP_CHECK" ]; then
    echo "INFO: Setting up kira environment variables"
    touch $CARGO_ENV

    # remove & disable system crash notifications
    rm -f /var/crash/*
    CDHelper text lineswap --insert="enabled=0" --prefix="enabled=" --path=/etc/default/apport --append-if-found-not=True

    CDHelper text lineswap --insert="KIRA_REGISTRY_SUBNET=$KIRA_REGISTRY_SUBNET" --prefix="KIRA_REGISTRY_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_VALIDATOR_SUBNET=$KIRA_VALIDATOR_SUBNET" --prefix="KIRA_VALIDATOR_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SENTRY_SUBNET=$KIRA_SENTRY_SUBNET" --prefix="KIRA_SENTRY_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SERVICE_SUBNET=$KIRA_SERVICE_SUBNET" --prefix="KIRA_SERVICE_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="HOSTS_PATH=$HOSTS_PATH" --prefix="HOSTS_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="DOCKER_COMMON=$DOCKER_COMMON" --prefix="DOCKER_COMMON=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRAMGR_SCRIPTS=$KIRAMGR_SCRIPTS" --prefix="KIRAMGR_SCRIPTS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="SOURCES_LIST=$SOURCES_LIST" --prefix="SOURCES_LIST=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_IMG=$KIRA_IMG" --prefix="KIRA_IMG=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="ETC_PROFILE=$ETC_PROFILE" --prefix="ETC_PROFILE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_STATE=$KIRA_STATE" --prefix="KIRA_STATE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_REGISTRY_PORT=$KIRA_REGISTRY_PORT" --prefix="KIRA_REGISTRY_PORT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_REGISTRY_NAME=$KIRA_REGISTRY_NAME" --prefix="KIRA_REGISTRY_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_REGISTRY_IP=$KIRA_REGISTRY_IP" --prefix="KIRA_REGISTRY_IP=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_VALIDATOR_IP=$KIRA_VALIDATOR_IP" --prefix="KIRA_VALIDATOR_IP=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SENTRY_IP=$KIRA_SENTRY_IP" --prefix="KIRA_SENTRY_IP=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_INTERX_IP=$KIRA_INTERX_IP" --prefix="KIRA_INTERX_IP=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_FRONTEND_IP=$KIRA_FRONTEND_IP" --prefix="KIRA_FRONTEND_IP=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_REGISTRY=$KIRA_REGISTRY" --prefix="KIRA_REGISTRY=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_DOCKER=$KIRA_DOCKER" --prefix="KIRA_DOCKER=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="NGINX_CONFIG=$NGINX_CONFIG" --prefix="NGINX_CONFIG=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="NGINX_SERVICED_PATH=$NGINX_SERVICED_PATH" --prefix="NGINX_SERVICED_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="RUSTFLAGS=$RUSTFLAGS" --prefix="RUSTFLAGS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="DOTNET_ROOT=$DOTNET_ROOT" --prefix="DOTNET_ROOT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="PATH=$PATH" --prefix="PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="DARTBIN=$DARTBIN" --prefix="DARTBIN=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FLUTTERROOT=$FLUTTERROOT" --prefix="FLUTTERROOT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="FLUTTERBIN=$FLUTTERBIN" --prefix="FLUTTERBIN=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="BREWBIN=$BREWBIN" --prefix="BREWBIN=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="MANPATH=$MANPATH" --prefix="MANPATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="INFOPATH=$INFOPATH" --prefix="INFOPATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="VALIDATOR_P2P_PORT=$VALIDATOR_P2P_PORT" --prefix="VALIDATOR_P2P_PORT=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="RPC_PROXY_PORT=$RPC_PROXY_PORT" --prefix="RPC_PROXY_PORT=" --path=$ETC_PROFILE --append-if-found-not=True

    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$DARTBIN" --prefix="PATH=" --and-contains-not=":$DARTBIN" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$FLUTTERBIN" --prefix="PATH=" --and-contains-not=":$FLUTTERBIN" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e
    CDHelper text lineswap --insert="PATH=$PATH:$BREWBIN" --prefix="PATH=" --and-contains-not=":$BREWBIN" --path=$ETC_PROFILE
    set +e && source "/etc/profile" &>/dev/null && set -e

    CDHelper text lineswap --insert="source $ETC_PROFILE" --prefix="source $ETC_PROFILE" --path=$BASHRC --append-if-found-not=True
    CDHelper text lineswap --insert="source $CARGO_ENV" --prefix="source $CARGO_ENV" --path=$BASHRC --append-if-found-not=True
    chmod 555 $BASHRC

    touch $SETUP_CHECK
else
    echo "INFO: Kira environment variables were already set"
fi
