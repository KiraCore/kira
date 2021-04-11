#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e

USE_DEFAULTS=$1

[ -z "$USE_DEFAULTS" ] && USE_DEFAULTS="true"

SEKAI_BRANCH_DEFAULT=$SEKAI_BRANCH
FRONTEND_BRANCH_DEFAULT=$FRONTEND_BRANCH
INTERX_BRANCH_DEFAULT=$INTERX_BRANCH

# All branches should have the same name across all repos to be considered compatible
if [ "$INFRA_BRANCH" == "master" ] || [[ $INFRA_BRANCH == mainnet* ]] || [[ $INFRA_BRANCH == testnet* ]] ; then
    DEFAULT_BRANCH="$INFRA_BRANCH"
else
    DEFAULT_BRANCH="master"
fi

[ -z "$SEKAI_BRANCH_DEFAULT" ] && SEKAI_BRANCH_DEFAULT="$DEFAULT_BRANCH"
[ -z "$FRONTEND_BRANCH_DEFAULT" ] && FRONTEND_BRANCH_DEFAULT="$DEFAULT_BRANCH"
[ -z "$INTERX_BRANCH_DEFAULT" ] && INTERX_BRANCH_DEFAULT="$DEFAULT_BRANCH"

if [ "${USE_DEFAULTS,,}" != "true" ] ; then
    echo -en "\e[31;1mPlease select branches for each repository, [ENTER] if default\e[0m" && echo -n ""
    
    read -p "Input SEKAI Branch (Default: $SEKAI_BRANCH_DEFAULT): " SEKAI_BRANCH
    read -p "Input FRONTEND Branch (Default: $FRONTEND_BRANCH_DEFAULT): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: $INTERX_BRANCH_DEFAULT): " INTERX_BRANCH
fi

[ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT
[ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT
[ -z "$INTERX_BRANCH" ] && INTERX_BRANCH=$INTERX_BRANCH_DEFAULT

echo -en "\e[33;1mINFO: SEKAI branch '$SEKAI_BRANCH' was selected\e[0m" && echo -n ""
echo -en "\e[33;1mINFO: FRONTEND branch '$FRONTEND_BRANCH' was selected\e[0m" && echo -n ""
echo -en "\e[33;1mINFO: INTERX branch '$INTERX_BRANCH' was selected\e[0m" && echo -n ""

[ "${USE_DEFAULTS,,}" != "true" ] && echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo -n ""

CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
