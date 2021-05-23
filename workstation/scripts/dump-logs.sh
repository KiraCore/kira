#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/dump-logs.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

NAME=$1
DUMP_ZIP=$2 # defines if all dumped files should be dumed at the end of execution
ID=$(globGet "${NAME}_ID")
CONTAINER_DUMP="$KIRA_DUMP/${NAME,,}"
COMMON_PATH="$DOCKER_COMMON/$NAME"
COMMON_LOGS="$COMMON_PATH/logs"
START_LOGS="$COMMON_LOGS/start.log"
HEALTH_LOGS="$COMMON_LOGS/health.log"
mkdir -p "$CONTAINER_DUMP" "$COMMON_PATH"
[ -z "$DUMP_ZIP" ] && DUMP_ZIP="false"

set +x
echoWarn "------------------------------------------------"
echoWarn "|          STARTED: DUMP LOGS v0.0.2           |"
echoWarn "------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|   CONTAINER ID: $ID"
echoWarn "|    ZIP RESULTS: $DUMP_ZIP"
echoWarn "| CONTAINER DUMP: $CONTAINER_DUMP"
echoWarn "------------------------------------------------"
set -x

rm -rfv $CONTAINER_DUMP
mkdir -p $CONTAINER_DUMP

if [ -z $ID ] ; then
    echo "WARNING: Can't dump files from $NAME container because it does not exists"
    exit 0
fi

echoInfo "INFO: Dumping old container logs..."
globGet "${CONTAINER_NAME}_HEALTH_LOG_OLD" > "$CONTAINER_DUMP/health.log.old.txt"
globGet "${CONTAINER_NAME}_START_LOG_OLD" > "$CONTAINER_DUMP/start.log.old.txt" 

docker exec -i $NAME printenv > $CONTAINER_DUMP/env.txt || echoWarn "WARNING: Failed to fetch environment variables"
echo $(docker inspect $ID || echo -n "") > $CONTAINER_DUMP/inspect.json || echoWarn "WARNING: Failed to inspect container $NAME"

if [[ "${NAME,,}" =~ ^(validator|sentry|priv_sentry|snapshot|seed)$ ]] ; then
    DUMP_CONFIG="$CONTAINER_DUMP/.sekaid/config"
    DUMP_DATA="$CONTAINER_DUMP/.sekaid/data"
    mkdir -p $DUMP_CONFIG
    mkdir -p $DUMP_DATA

    echoInfo "INFO: Dumping config files..."
    timeout 60 docker cp $NAME:$SEKAID_HOME/config/addrbook.json $DUMP_CONFIG/addrbook.json || echoWarn "WARNING: Failed to dump address book file"
    timeout 60 docker cp $NAME:$SEKAID_HOME/config/app.toml $DUMP_CONFIG/app.toml || echoWarn "WARNING: Failed to dump app toml file"
    timeout 60 docker cp $NAME:$SEKAID_HOME/config/config.toml $DUMP_CONFIG/config.toml || echoWarn "WARNING: Failed to dump config toml file"

    echoInfo "INFO: Dumping data files..."
    timeout 60 docker cp $NAME:$SEKAID_HOME/data/priv_validator_state.json $DUMP_DATA/priv_validator_state.json || echoWarn "WARNING: Failed to dump address book file"
elif [ "${NAME,,}" == "interx" ] ; then
    echoInfo "INFO: Dumping interx config files..."
    timeout 60 docker cp $NAME:/home/go/src/github.com/kiracore/sekai/INTERX/config.json $DUMP_CONFIG/config.json || echoWarn "WARNING: Failed to dump config file"
fi

docker logs --details --timestamps $ID > $CONTAINER_DUMP/logs.txt || echoWarn "WARNING: Failed to dump $NAME container logs"
docker inspect --format "{{json .State.Health }}" "$ID" | jq '.Log[-1].Output' | sed 's/\\n/\n/g' > $CONTAINER_DUMP/healthcheck.txt || echoWarn "WARNING: Failed to dump $NAME container healthcheck logs"

if (! $(isFileEmpty $START_LOGS)) ; then
    cp -afv $START_LOGS $CONTAINER_DUMP/start.txt || echoWarn "WARNING: Failed to dump $NAME start logs"
else
    echoInfo "INFO: No start logs were found"
fi

if (! $(isFileEmpty $HEALTH_LOGS)) ; then
    cp -afv $HEALTH_LOGS $CONTAINER_DUMP/health.txt || echoWarn "WARNING: Failed to dump $NAME health logs"
else
    echoInfo "INFO: No health logs were found"
fi

if [ "${DUMP_ZIP,,}" == "true" ] ; then
    echoInfo "INFO: Compressing dump files..."
    ZIP_FILE="$CONTAINER_DUMP/${NAME,,}.zip"
    zip -9 -r -v $ZIP_FILE $CONTAINER_DUMP
else
    echoInfo "INFO: Container $NAME files will not be compressed in this run"
fi

set +x
echoInfo "INFO: Compressed all files into '$ZIP_FILE'"
echoInfo "INFO: Container ${NAME} loggs were dumped to $CONTAINER_DUMP"
echoWarn "------------------------------------------------"
echoWarn "|        FINISHED: DUMP LOGS    v0.0.2         |"
echoWarn "------------------------------------------------"
set -x