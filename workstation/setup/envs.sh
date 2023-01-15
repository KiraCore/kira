#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

INFRA_MODE="$(globGet INFRA_MODE)"

ETC_PROFILE="/etc/profile"  && setGlobEnv ETC_PROFILE "$ETC_PROFILE" 
HOSTS_PATH="/etc/hosts"     && setGlobEnv HOSTS_PATH "$HOSTS_PATH"

(! $(isPort "$(globGet DEFAULT_SSH_PORT)")) && globSet DEFAULT_SSH_PORT "22"

globSet DEFAULT_P2P_PORT "26656"
globSet DEFAULT_RPC_PORT "26657"
globSet DEFAULT_PROMETHEUS_PORT "26660"
globSet DEFAULT_GRPC_PORT "9090"
globSet DEFAULT_INTERX_PORT "11000"

globSet KIRA_SEED_P2P_PORT "16656"
globSet KIRA_SEED_RPC_PORT "16657"
globSet KIRA_SEED_GRPC_PORT "19090"
globSet KIRA_SEED_PROMETHEUS_PORT "16660"

globSet KIRA_SENTRY_RPC_PORT "26657"
globSet KIRA_SENTRY_P2P_PORT "26656"
globSet KIRA_SENTRY_GRPC_PORT "29090"
globSet KIRA_SENTRY_PROMETHEUS_PORT "26660"

globSet KIRA_VALIDATOR_P2P_PORT "36656"
globSet KIRA_VALIDATOR_RPC_PORT "36657"
globSet KIRA_VALIDATOR_GRPC_PORT "39090"
globSet KIRA_VALIDATOR_PROMETHEUS_PORT "36660"

(! $(isPort "$(globGet CUSTOM_P2P_PORT)"))        && globSet CUSTOM_P2P_PORT "$(globGet "KIRA_${INFRA_MODE}_P2P_PORT")"
(! $(isPort "$(globGet CUSTOM_RPC_PORT)"))        && globSet CUSTOM_RPC_PORT "$(globGet "KIRA_${INFRA_MODE}_RPC_PORT")"
(! $(isPort "$(globGet CUSTOM_GRPC_PORT)"))       && globSet CUSTOM_GRPC_PORT "$(globGet "KIRA_${INFRA_MODE}_GRPC_PORT")"
(! $(isPort "$(globGet CUSTOM_PROMETHEUS_PORT)")) && globSet CUSTOM_PROMETHEUS_PORT "$(globGet "KIRA_${INFRA_MODE}_PROMETHEUS_PORT")"
(! $(isPort "$(globGet CUSTOM_INTERX_PORT)"))     && globSet CUSTOM_INTERX_PORT "$(globGet DEFAULT_INTERX_PORT)"

KIRA_DOCEKR_SUBNET="10.1.0.0/16"        && globSet KIRA_DOCEKR_SUBNET "$KIRA_DOCEKR_SUBNET" 
KIRA_DOCEKR_NETWORK="kiranet"           && globSet KIRA_DOCEKR_NETWORK "$KIRA_DOCEKR_NETWORK" 

KIRA_DOCKER="$KIRA_INFRA/docker"                                && setGlobEnv KIRA_DOCKER "$KIRA_DOCKER"
KIRAMGR_SCRIPTS="$KIRA_MANAGER/launch"                          && setGlobEnv KIRAMGR_SCRIPTS "$KIRAMGR_SCRIPTS"
INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"    && setGlobEnv INTERX_REFERENCE_DIR "$INTERX_REFERENCE_DIR"

globSet INFRA_MODE "$INFRA_MODE" $GLOBAL_COMMON_RO
globSet SNAPSHOT_TARGET "$INFRA_MODE"
globSet FIREWALL_ZONE "$INFRA_MODE"

# remove & disable system crash notifications
rm -f /var/crash/*
mkdir -p "/etc/default" && touch /etc/default/apport
setLastLineByPrefixOrAppend "enabled=" "enabled=0" /etc/default/apport

