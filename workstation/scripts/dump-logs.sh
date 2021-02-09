#!/bin/bash
exec 2>&1

set +e && source "/etc/profile" &>/dev/null && set -e

NAME=$1
DUMP_ZIP=$2 # defines if all dumped files should be dumed at the end of execution
CONTAINER_DUMP="$KIRA_DUMP/infra/${NAME,,}"
HALT_FILE="$DOCKER_COMMON/$NAME/halt"
mkdir -p "$CONTAINER_DUMP" "$DOCKER_COMMON/$NAME"

[ -z "$DUMP_ZIP" ] && DUMP_ZIP="false"
HALT_FILE_EXISTED="true" && [ ! -f "$HALT_FILE" ] && HALT_FILE_EXISTED="false" && touch $HALT_FILE

set +x
echo "------------------------------------------------"
echo "|          STARTED: DUMP LOGS v0.0.2           |"
echo "------------------------------------------------"
echo "| CONTAINER NAME: $NAME"
echo "|    ZIP RESULTS: $DUMP_ZIP"
echo "| CONTAINER DUMP: $CONTAINER_DUMP"
echo "------------------------------------------------"
set -x

rm -rfv $CONTAINER_DUMP
mkdir -p $CONTAINER_DUMP

ID=$($KIRA_SCRIPTS/container-id.sh "$NAME")
if [ -z $ID ] ; then
    echo "WARNING: Can't dump files from $NAME container because it does not exists"
    exit 0
fi

docker exec -i $NAME printenv > $CONTAINER_DUMP/env.txt || echo "WARNING: Failed to fetch environment variables"
echo $(docker inspect $ID || echo "") > $CONTAINER_DUMP/inspect.json || echo "WARNING: Failed to inspect container $NAME"

if [ "$NAME" == "validator" ] || [ "$NAME" == "sentry" ] ; then
    DUMP_CONFIG="$CONTAINER_DUMP/.sekaid/config"
    DUMP_DATA="$CONTAINER_DUMP/.sekaid/data"
    mkdir -p $DUMP_CONFIG
    mkdir -p $DUMP_DATA

    echo "INFO: Dumping config files..."
    docker cp $NAME:$SEKAID_HOME/config/addrbook.json $DUMP_CONFIG/addrbook.json || echo "WARNING: Failed to dump address book file"
    docker cp $NAME:$SEKAID_HOME/config/app.toml $DUMP_CONFIG/app.toml || echo "WARNING: Failed to dump app toml file"
    docker cp $NAME:$SEKAID_HOME/config/config.toml $DUMP_CONFIG/config.toml || echo "WARNING: Failed to dump config toml file"
    docker cp $NAME:$SEKAID_HOME/config/genesis.json $DUMP_CONFIG/genesis.json || echo "WARNING: Failed to dump genesis file"

    echo "INFO: Dumping data files..."
    docker cp $NAME:$SEKAID_HOME/data/priv_validator_state.json $DUMP_DATA/priv_validator_state.json || echo "WARNING: Failed to dump address book file"
fi

docker container logs --details --timestamps $ID > $CONTAINER_DUMP/logs.txt || echo "WARNING: Failed to dump $NAME container logs"

[ "${HALT_FILE_EXISTED,,}" == "false" ] && rm -fv touch $HALT_FILE

if [ "${DUMP_ZIP,,}" == "true" ] ; then
    echo "INFO: Compressing dump files..."
    
    ZIP_FILE="$CONTAINER_DUMP/${NAME,,}.zip"
    zip -9 -r -v $ZIP_FILE $CONTAINER_DUMP
else
    echo "INFO: Container $NAME files will not be compressed in this run"
fi

set +x
echo "INFO: Compressed all files into '$ZIP_FILE'"
echo "INFO: Container ${NAME} loggs were dumped to $CONTAINER_DUMP"

echo "------------------------------------------------"
echo "|        FINISHED: DUMP LOGS    v0.0.2         |"
echo "------------------------------------------------"
set -x