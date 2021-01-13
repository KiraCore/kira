#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e

USE_DEFAULTS=$1

[ -z "$USE_DEFAULTS" ] && USE_DEFAULTS="true"

SEKAI_BRANCH_DEFAULT=$SEKAI_BRANCH
FRONTEND_BRANCH_DEFAULT=$FRONTEND_BRANCH
INTERX_BRANCH_DEFAULT=$INTERX_BRANCH

[ -z "$SEKAI_BRANCH_DEFAULT" ] && SEKAI_BRANCH_DEFAULT="master"
[ -z "$FRONTEND_BRANCH_DEFAULT" ] && FRONTEND_BRANCH_DEFAULT="master"
[ -z "$INTERX_BRANCH_DEFAULT" ] && INTERX_BRANCH_DEFAULT="master"

if [ "${USE_DEFAULTS,,}" != "true" ] ; then
    echo -en "\e[31;1mPlease select branches for each repository, [ENTER] if default\e[0m" && echo ""
    
    read -p "Input SEKAI Branch (Default: $SEKAI_BRANCH_DEFAULT): " SEKAI_BRANCH
    read -p "Input FRONTEND Branch (Default: $FRONTEND_BRANCH_DEFAULT): " FRONTEND_BRANCH
    read -p "Input INTERX Branch (Default: $INTERX_BRANCH_DEFAULT): " INTERX_BRANCH
fi

[ -z "$SEKAI_BRANCH" ] && SEKAI_BRANCH=$SEKAI_BRANCH_DEFAULT
[ -z "$FRONTEND_BRANCH" ] && FRONTEND_BRANCH=$FRONTEND_BRANCH_DEFAULT
[ -z "$INTERX_BRANCH" ] && INTERX_BRANCH=$INTERX_BRANCH_DEFAULT

echo -en "\e[33;1mINFO: SEKAI branch '$SEKAI_BRANCH' was selected\e[0m" && echo ""
echo -en "\e[33;1mINFO: FRONTEND branch '$FRONTEND_BRANCH' was selected\e[0m" && echo ""
echo -en "\e[33;1mINFO: INTERX branch '$INTERX_BRANCH' was selected\e[0m" && echo ""

[ "${USE_DEFAULTS,,}" != "true" ] && echo -en "\e[31;1mPress any key to continue or Ctrl+C to abort...\e[0m" && read -n 1 -s && echo ""

CDHelper text lineswap --insert="SEKAI_BRANCH=$SEKAI_BRANCH" --prefix="SEKAI_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FRONTEND_BRANCH=$FRONTEND_BRANCH" --prefix="FRONTEND_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_BRANCH=$INTERX_BRANCH" --prefix="INTERX_BRANCH=" --path=$ETC_PROFILE --append-if-found-not=True
