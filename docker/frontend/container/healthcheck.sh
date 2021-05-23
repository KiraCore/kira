#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

HEALTHCHECK_COUNTER=$(globGet HEALTHCHECK_COUNTER)
($(isNaturalNumber $HEALTHCHECK_COUNTER)) && HEALTHCHECK_COUNTER="$(($HEALTHCHECK_COUNTER+1))" || HEALTHCHECK_COUNTER=0
globSet HEALTHCHECK_COUNTER $HEALTHCHECK_COUNTER

[ "$HEALTHCHECK_COUNTER" == "0" ] && [ -f "${COMMON_LOGS}/health.log" ] && cp -afv "${COMMON_LOGS}/health.log.old"

/bin/sh -c "/bin/bash ${SELF_CONTAINER}/defaultcheck.sh | tee -a ${COMMON_LOGS}/health.log ; test ${PIPESTATUS[0]} = 0"
