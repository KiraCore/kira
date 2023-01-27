#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

INFRA_MODE="$(globGet INFRA_MODE)"
if [ "$INFRA_MODE" != "validator" ] && [ "$INFRA_MODE" != "sentry" ] && [ "$INFRA_MODE" != "seed" ] ; then
    INFRA_MODE="validator"  && globSet INFRA_MODE "$INFRA_MODE"
fi
globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO

(! $(isPort "$(globGet DEFAULT_SSH_PORT)")) && globSet DEFAULT_SSH_PORT "22"

globSet DEFAULT_INTERX_PORT "11000"
globSet DEFAULT_P2P_PORT "26656"
globSet DEFAULT_RPC_PORT "26657"
globSet DEFAULT_PROMETHEUS_PORT "26660"
globSet DEFAULT_GRPC_PORT "9090"
globSet DEFAULT_DOCKER_SUBNET "10.1.0.0/16"
globSet DEFAULT_DOCKER_NETWORK "kiranet"

if ($(isWSL)) ; then 
    CUSTOM_PORTS_EXPOSE="$((DEFAULT_INTERX_PORT + 100))-$((DEFAULT_INTERX_PORT + 108))"
    CUSTOM_PORTS_EXPOSE=",$CUSTOM_PORTS_EXPOSE$((DEFAULT_P2P_PORT + 100))-$((DEFAULT_P2P_PORT + 108))"
    CUSTOM_PORTS_EXPOSE=",$CUSTOM_PORTS_EXPOSE$((DEFAULT_RPC_PORT + 100))-$((DEFAULT_RPC_PORT + 108))"
    CUSTOM_PORTS_EXPOSE=",$CUSTOM_PORTS_EXPOSE$((DEFAULT_PROMETHEUS_PORT + 100))-$((DEFAULT_PROMETHEUS_PORT + 108))"
    CUSTOM_PORTS_EXPOSE=",$CUSTOM_PORTS_EXPOSE$((DEFAULT_GRPC_PORT + 100))-$((DEFAULT_GRPC_PORT + 108))"
    CUSTOM_PORTS_EXPOSE=",80,443"
    globSet CUSTOM_PORTS_EXPOSE "$CUSTOM_PORTS_EXPOSE"
fi

KIRA_SEED_P2P_PORT="16656"              && globSet KIRA_SEED_P2P_PORT "$KIRA_SEED_P2P_PORT"
KIRA_SEED_RPC_PORT="16657"              && globSet KIRA_SEED_RPC_PORT "$KIRA_SEED_RPC_PORT"
KIRA_SEED_GRPC_PORT="19090"             && globSet KIRA_SEED_GRPC_PORT "$KIRA_SEED_GRPC_PORT"
KIRA_SEED_PROMETHEUS_PORT="16660"       && globSet KIRA_SEED_PROMETHEUS_PORT "$KIRA_SEED_PROMETHEUS_PORT"

KIRA_SENTRY_P2P_PORT="26656"            && globSet KIRA_SENTRY_P2P_PORT "$KIRA_SENTRY_P2P_PORT"
KIRA_SENTRY_RPC_PORT="26657"            && globSet KIRA_SENTRY_RPC_PORT "$KIRA_SENTRY_RPC_PORT"
KIRA_SENTRY_GRPC_PORT="29090"           && globSet KIRA_SENTRY_GRPC_PORT "$KIRA_SENTRY_GRPC_PORT"
KIRA_SENTRY_PROMETHEUS_PORT="26660"     && globSet KIRA_SENTRY_PROMETHEUS_PORT "$KIRA_SENTRY_PROMETHEUS_PORT"

KIRA_VALIDATOR_P2P_PORT="36656"         && globSet KIRA_VALIDATOR_P2P_PORT "$KIRA_VALIDATOR_P2P_PORT"
KIRA_VALIDATOR_RPC_PORT="36657"         && globSet KIRA_VALIDATOR_RPC_PORT "$KIRA_VALIDATOR_RPC_PORT"
KIRA_VALIDATOR_GRPC_PORT="39090"        && globSet KIRA_VALIDATOR_GRPC_PORT "$KIRA_VALIDATOR_GRPC_PORT"
KIRA_VALIDATOR_PROMETHEUS_PORT="36660"  && globSet KIRA_VALIDATOR_PROMETHEUS_PORT "$KIRA_VALIDATOR_PROMETHEUS_PORT"

# reset ports if they are set to incorrect node type (e.g. validator can't use seed node P2P port)
CUSTOM_P2P_PORT=$(globGet CUSTOM_P2P_PORT)
CUSTOM_RPC_PORT=$(globGet CUSTOM_RPC_PORT)
CUSTOM_GRPC_PORT=$(globGet CUSTOM_GRPC_PORT)
CUSTOM_PROMETHEUS_PORT=$(globGet CUSTOM_PROMETHEUS_PORT)
if [ "$INFRA_MODE" == "seed" ] ; then
    ([ "$CUSTOM_P2P_PORT" == "$KIRA_SENTRY_P2P_PORT" ] || [ "$CUSTOM_P2P_PORT" == "$KIRA_VALIDATOR_P2P_PORT" ]) && CUSTOM_P2P_PORT=""
    ([ "$CUSTOM_RPC_PORT" == "$KIRA_SENTRY_RPC_PORT" ] || [ "$CUSTOM_RPC_PORT" == "$KIRA_VALIDATOR_RPC_PORT" ]) && CUSTOM_RPC_PORT=""
    ([ "$CUSTOM_GRPC_PORT" == "$KIRA_SENTRY_GRPC_PORT" ] || [ "$CUSTOM_GGRPC_PORT" == "$KIRA_VALIDATOR_GP2P_PORT" ]) && CUSTOM_GRPC_PORT=""
    ([ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_SENTRY_PROMETHEUS_PORT" ] || [ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_VALIDATOR_PROMETHEUS_PORT" ]) && CUSTOM_PROMETHEUS_PORT=""
elif [ "$INFRA_MODE" == "sentry" ] ; then
    ([ "$CUSTOM_P2P_PORT" == "$KIRA_SEED_P2P_PORT" ] || [ "$CUSTOM_P2P_PORT" == "$KIRA_VALIDATOR_P2P_PORT" ]) && CUSTOM_P2P_PORT=""
    ([ "$CUSTOM_RPC_PORT" == "$KIRA_SEED_RPC_PORT" ] || [ "$CUSTOM_RPC_PORT" == "$KIRA_VALIDATOR_RPC_PORT" ]) && CUSTOM_RPC_PORT=""
    ([ "$CUSTOM_GRPC_PORT" == "$KIRA_SEED_GRPC_PORT" ] || [ "$CUSTOM_GRPC_PORT" == "$KIRA_VALIDATOR_GRPC_PORT" ]) && CUSTOM_GRPC_PORT=""
    ([ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_SEED_PROMETHEUS_PORT" ] || [ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_VALIDATOR_PROMETHEUS_PORT" ]) && CUSTOM_PROMETHEUS_PORT=""
elif [ "$INFRA_MODE" == "validator" ] ; then
    ([ "$CUSTOM_P2P_PORT" == "$KIRA_SENTRY_P2P_PORT" ] || [ "$CUSTOM_P2P_PORT" == "$KIRA_SEED_P2P_PORT" ]) && CUSTOM_P2P_PORT=""
    ([ "$CUSTOM_RPC_PORT" == "$KIRA_SENTRY_RPC_PORT" ] || [ "$CUSTOM_RPC_PORT" == "$KIRA_SEED_RPC_PORT" ]) && CUSTOM_RPC_PORT=""
    ([ "$CUSTOM_GRPC_PORT" == "$KIRA_SENTRY_GRPC_PORT" ] || [ "$CUSTOM_GRPC_PORT" == "$KIRA_SEED_GRPC_PORT" ]) && CUSTOM_GRPC_PORT=""
    ([ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_SENTRY_PROMETHEUS_PORT" ] || [ "$CUSTOM_PROMETHEUS_PORT" == "$KIRA_SEED_PROMETHEUS_PORT" ]) && CUSTOM_PROMETHEUS_PORT=""
fi

(! $(isPort "$CUSTOM_P2P_PORT"))                && globSet CUSTOM_P2P_PORT "$(globGet "KIRA_${INFRA_MODE}_P2P_PORT")"
(! $(isPort "$CUSTOM_RPC_PORT"))                && globSet CUSTOM_RPC_PORT "$(globGet "KIRA_${INFRA_MODE}_RPC_PORT")"
(! $(isPort "$CUSTOM_GRPC_PORT"))               && globSet CUSTOM_GRPC_PORT "$(globGet "KIRA_${INFRA_MODE}_GRPC_PORT")"
(! $(isPort "$CUSTOM_PROMETHEUS_PORT"))         && globSet CUSTOM_PROMETHEUS_PORT "$(globGet "KIRA_${INFRA_MODE}_PROMETHEUS_PORT")"
(! $(isPort "$(globGet CUSTOM_INTERX_PORT)"))   && globSet CUSTOM_INTERX_PORT "$(globGet DEFAULT_INTERX_PORT)"

[ -z "$KIRA_DOCKER_SUBNET" ]  && KIRA_DOCKER_SUBNET="$(globGet DEFAULT_DOCKER_SUBNET)"   && globSet KIRA_DOCKER_SUBNET "$KIRA_DOCKER_SUBNET" 
[ -z "$KIRA_DOCKER_NETWORK" ] && KIRA_DOCKER_NETWORK="$(globGet DEFAULT_DOCKER_NETWORK)" && globSet KIRA_DOCKER_NETWORK "$KIRA_DOCKER_NETWORK" 

KIRA_DOCKER="$KIRA_INFRA/docker"                                    && setGlobEnv KIRA_DOCKER "$KIRA_DOCKER"
KIRAMGR_SCRIPTS="$KIRA_MANAGER/launch"                              && setGlobEnv KIRAMGR_SCRIPTS "$KIRAMGR_SCRIPTS"
INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"        && setGlobEnv INTERX_REFERENCE_DIR "$INTERX_REFERENCE_DIR"

globSet SNAPSHOT_TARGET "$INFRA_MODE"
globSet FIREWALL_ZONE "$INFRA_MODE"

# defines if node should be able to communicate with other local nodes (true), or only private ones (false)
[ "$(globGet PRIVATE_MODE)" != "true" ] && globSet PRIVATE_MODE "false"

# defines if node should be making snapshots immediately after launch, by default no snaps on launch
[ "$(globGet SNAPSHOT_EXECUTE)" != "true" ] && globSet SNAPSHOT_EXECUTE "false"

# by default do NOT sync from snapshoots
[ "$(globGet SNAPSHOT_SYNC)" != "true" ] && globSet SNAPSHOT_SYNC "false"

# defines if new network should be launched (default false)
[ "$(globGet NEW_NETWORK)" != "true" ] && globSet NEW_NETWORK "false"

[ -z "(globGet TRUSTED_NODE_ADDR)" ] && globSet TRUSTED_NODE_ADDR "0.0.0.0"

globSet KIRA_SETUP_VER "$(globGet KIRA_SETUP_VER)" $GLOBAL_COMMON_RO

(! $(isBoolean $(globGet FIREWALL_ENABLED))) && globSet FIREWALL_ENABLED "true"

# if new base docker image is not defined then default it to old one
[ -z "$(globGet NEW_BASE_IMAGE_SRC)" ] && globSet NEW_BASE_IMAGE_SRC "$(globGet BASE_IMAGE_SRC)"

# default network interface
[ -z "$(globGet IFACE)" ] && globSet IFACE "$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)"
if [ -z "$(globGet MTU)" ] ; then
    MTU=$(cat /sys/class/net/$(globGet IFACE)/mtu || echo "1500")
    (! $(isNaturalNumber $MTU)) && MTU=1500
    (($MTU < 100)) && MTU=900
    globSet MTU $MTU
fi

[ -z "$(globGet PORTS_EXPOSURE)" ] && globSet PORTS_EXPOSURE "enabled"

# remove & disable system crash notifications
rm -f /var/crash/*
mkdir -p "/etc/default" && touch /etc/default/apport
setLastLineByPrefixOrAppend "enabled=" "enabled=0" /etc/default/apport

