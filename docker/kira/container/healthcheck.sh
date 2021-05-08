#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

# rate limit not to overextend the log files
sleep 10
/bin/sh -c "/bin/bash ${SELF_CONTAINER}/defaultcheck.sh | tee -a ${COMMON_LOGS}/health.log ; test ${PIPESTATUS[0]} = 0"
