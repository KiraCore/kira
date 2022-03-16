#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

BASHRC=~/.bashrc
ETC_PROFILE="/etc/profile"

CARGO_ENV="/home/$KIRA_USER/.cargo/env"

KIRA_STATE=/kira/state
KIRA_REGISTRY_SUBNET="10.1.0.0/16"
KIRA_SENTRY_SUBNET="10.2.0.0/16"
KIRA_SERVICE_SUBNET="10.3.0.0/16"

KIRA_REGISTRY_NETWORK="regnet"
KIRA_SENTRY_NETWORK="sentrynet"
KIRA_INTERX_NETWORK="servicenet"

KIRA_REGISTRY_DNS="registry.local"
KIRA_VALIDATOR_DNS="validator.local"
KIRA_SENTRY_DNS="sentry.local"
KIRA_SEED_DNS="seed.local"
KIRA_INTERX_DNS="interx.local"

KIRA_REGISTRY="$KIRA_REGISTRY_DNS:$KIRA_REGISTRY_PORT"

KIRA_IMG="$KIRA_INFRA/common/img"
KIRA_DOCKER="$KIRA_INFRA/docker"
KIRAMGR_SCRIPTS="$KIRA_MANAGER/scripts"

HOSTS_PATH="/etc/hosts"
NGINX_SERVICED_PATH="/etc/systemd/system/nginx.service.d"
NGINX_CONFIG="/etc/nginx/nginx.conf"

RUSTFLAGS="-Ctarget-feature=+aes,+ssse3"
DOTNET_ROOT="/usr/bin/dotnet"
SOURCES_LIST="/etc/apt/sources.list.d"

DARTBIN="/usr/lib/dart/bin"
FLUTTERROOT="/usr/lib/flutter"
FLUTTERBIN="$FLUTTERROOT/bin"

BREWBIN="/home/$KIRA_USER/.linuxbrew/bin"
MANPATH="/home/$KIRA_USER/.linuxbrew/share/man:\$MANPATH"
INFOPATH="/home/$KIRA_USER/.linuxbrew/share/info:\$INFOPATH"

mkdir -p "$KIRA_STATE" "/home/$KIRA_USER/.cargo" "/home/$KIRA_USER/Desktop" "$SOURCES_LIST"

ESSENTIALS_HASH=$(echo "$KIRA_USER-$KIRA_INFRA-$KIRA_MANAGER-$FLUTTERROOT-" | md5)
SETUP_CHECK="$KIRA_SETUP/kira-env-7-$ESSENTIALS_HASH"
if [ ! -f "$SETUP_CHECK" ]; then
    echoInfo "INFO: Setting up kira environment variables"
    touch $CARGO_ENV

    # remove & disable system crash notifications
    rm -f /var/crash/*
    touch /etc/default/apport
    CDHelper text lineswap --insert="enabled=0" --prefix="enabled=" --path=/etc/default/apport --append-if-found-not=True

    CDHelper text lineswap --insert="KIRA_REGISTRY_DNS=\"$KIRA_REGISTRY_DNS\"" --prefix="KIRA_REGISTRY_DNS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_VALIDATOR_DNS=\"$KIRA_VALIDATOR_DNS\"" --prefix="KIRA_VALIDATOR_DNS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SENTRY_DNS=\"$KIRA_SENTRY_DNS\"" --prefix="KIRA_SENTRY_DNS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SEED_DNS=\"$KIRA_SEED_DNS\"" --prefix="KIRA_SEED_DNS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_INTERX_DNS=\"$KIRA_INTERX_DNS\"" --prefix="KIRA_INTERX_DNS=" --path=$ETC_PROFILE --append-if-found-not=True

    CDHelper text lineswap --insert="KIRA_REGISTRY_SUBNET=\"$KIRA_REGISTRY_SUBNET\"" --prefix="KIRA_REGISTRY_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SENTRY_SUBNET=\"$KIRA_SENTRY_SUBNET\"" --prefix="KIRA_SENTRY_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SERVICE_SUBNET=\"$KIRA_SERVICE_SUBNET\"" --prefix="KIRA_SERVICE_SUBNET=" --path=$ETC_PROFILE --append-if-found-not=True

    CDHelper text lineswap --insert="HOSTS_PATH=$HOSTS_PATH" --prefix="HOSTS_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRAMGR_SCRIPTS=$KIRAMGR_SCRIPTS" --prefix="KIRAMGR_SCRIPTS=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="SOURCES_LIST=$SOURCES_LIST" --prefix="SOURCES_LIST=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_IMG=$KIRA_IMG" --prefix="KIRA_IMG=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="ETC_PROFILE=$ETC_PROFILE" --prefix="ETC_PROFILE=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_STATE=$KIRA_STATE" --prefix="KIRA_STATE=" --path=$ETC_PROFILE --append-if-found-not=True

    CDHelper text lineswap --insert="KIRA_REGISTRY_NETWORK=$KIRA_REGISTRY_NETWORK" --prefix="KIRA_REGISTRY_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_SENTRY_NETWORK=$KIRA_SENTRY_NETWORK" --prefix="KIRA_SENTRY_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="KIRA_INTERX_NETWORK=$KIRA_INTERX_NETWORK" --prefix="KIRA_INTERX_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True

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

    CDHelper text lineswap --insert="INTERX_REFERENCE_DIR=$DOCKER_COMMON/interx/cache/reference" --prefix="INTERX_REFERENCE_DIR=" --path=$ETC_PROFILE --append-if-found-not=True

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
    echoInfo "INFO: Kira environment variables were already set"
fi
