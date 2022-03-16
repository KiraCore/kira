#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

/bin/sh -c "/bin/bash ${SELF_CONTAINER}/defaultcheck.sh | tee -a ${COMMON_LOGS}/health.log ; test ${PIPESTATUS[0]} = 0"
