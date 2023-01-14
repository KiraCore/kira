#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

ETC_PROFILE="/etc/profile"  && setGlobEnv ETC_PROFILE "$ETC_PROFILE" 
HOSTS_PATH="/etc/hosts"     && setGlobEnv HOSTS_PATH "$HOSTS_PATH"

[ -z "$DEFAULT_SSH_PORT" ] && \
DEFAULT_SSH_PORT="22"                   && setGlobEnv DEFAULT_SSH_PORT "$DEFAULT_SSH_PORT"

DEFAULT_P2P_PORT="26656"                && setGlobEnv DEFAULT_P2P_PORT "$DEFAULT_P2P_PORT"
DEFAULT_RPC_PORT="26657"                && setGlobEnv DEFAULT_RPC_PORT "$DEFAULT_RPC_PORT"
DEFAULT_PROMETHEUS_PORT="26660"         && setGlobEnv DEFAULT_PROMETHEUS_PORT "$DEFAULT_PROMETHEUS_PORT"
DEFAULT_GRPC_PORT="9090"                && setGlobEnv DEFAULT_GRPC_PORT "$DEFAULT_GRPC_PORT"
DEFAULT_INTERX_PORT="11000"             && setGlobEnv DEFAULT_INTERX_PORT "$DEFAULT_INTERX_PORT"
        
#KIRA_REGISTRY_PORT="5000"               && setGlobEnv KIRA_REGISTRY_PORT "$KIRA_REGISTRY_PORT"
KIRA_INTERX_PORT="11000"                && setGlobEnv KIRA_INTERX_PORT "$KIRA_INTERX_PORT"

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

KIRA_DOCEKR_SUBNET="10.1.0.0/16"        && globSet KIRA_DOCEKR_SUBNET "$KIRA_DOCEKR_SUBNET" 
KIRA_DOCEKR_NETWORK="kiranet"           && globSet KIRA_DOCEKR_NETWORK "$KIRA_DOCEKR_NETWORK" 

KIRA_VALIDATOR_DNS="validator.local"    && setGlobEnv KIRA_VALIDATOR_DNS "$KIRA_VALIDATOR_DNS" 
KIRA_SENTRY_DNS="sentry.local"          && setGlobEnv KIRA_SENTRY_DNS "$KIRA_SENTRY_DNS" 
KIRA_SEED_DNS="seed.local"              && setGlobEnv KIRA_SEED_DNS "$KIRA_SEED_DNS" 
KIRA_INTERX_DNS="interx.local"          && setGlobEnv KIRA_INTERX_DNS "$KIRA_INTERX_DNS" 

KIRA_DOCKER="$KIRA_INFRA/docker"                                && setGlobEnv KIRA_DOCKER "$KIRA_DOCKER"
KIRAMGR_SCRIPTS="$KIRA_MANAGER/launch"                          && setGlobEnv KIRAMGR_SCRIPTS "$KIRAMGR_SCRIPTS"
INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"    && setGlobEnv INTERX_REFERENCE_DIR "$INTERX_REFERENCE_DIR"

# remove & disable system crash notifications
rm -f /var/crash/*
mkdir -p "/etc/default" && touch /etc/default/apport
setLastLineByPrefixOrAppend "enabled=" "enabled=0" /etc/default/apport

