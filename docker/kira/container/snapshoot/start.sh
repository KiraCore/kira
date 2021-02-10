#!/bin/bash
exec 2>&1
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echo "INFO: Staring snapshot v0.0.3"

EXECUTED_CHECK="$COMMON_DIR/executed"

SNAP_FILE="$COMMON_DIR/snap.zip"
DATA_DIR="$SEKAID_HOME/data"

CFG="$SEKAID_HOME/config/config.toml"
COMMON_CFG="$COMMON_DIR/config.toml"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_DIR/genesis.json"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"

DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

( [ -z "$HALT_HEIGHT" ] || [ $HALT_HEIGHT -le 0 ] ) && echo "ERROR: Invalid snapshot height, cant be less or equal to 0" && exit 1

echo "$SNAP_FILENAME" > $SNAP_LATEST

while [ -f "$SNAP_DONE" ] ; do
  echo "INFO: Snapshot was already finalized, nothing to do here"
  sleep 600
done

while ! ping -c1 sentry &>/dev/null ; do
  echo "INFO: Waiting for ping response form sentry node... ($(date))"
  sleep 5
done
echo "INFO: Sentry IP Found: $(getent hosts sentry | awk '{ print $1 }')"

while [ ! -f "$SNAP_FILE" ] && [ ! -f "$COMMON_GENESIS" ] ; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ] ; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id="$NETWORK_NAME" "KIRA SNAPSHOT NODE" --home=$SEKAID_HOME

  $SELF_CONTAINER/configure.sh

  rm -fv $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  
  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE -d $DATA_DIR
    DATA_GENESIS="$DATA_DIR/genesis.json"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS # move snapshot genesis into common folder
    fi

    rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present, starting new sync..."
  fi

  echo "INFO: Presering configuration file..."
  cp -f -v -a "$CFG" "$COMMON_CFG"

  echo "0" > $SNAP_PROGRESS
  touch $EXECUTED_CHECK
fi

touch ./output.log ./output2.log # make sure log files are present so we can cut them

LAST_SNAP_BLOCK=0
TOP_SNAP_BLOCK=0
FINISHED_RUNNING="false"
i=0
PID1=""
while : ; do
  echo "INFO: Checking node status..."
  SNAP_STATUS=$(sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "")
  SNAP_BLOCK=$(echo $SNAP_STATUS | jq -rc '.SyncInfo.latest_block_height' 2> /dev/null || echo "")
  ( [ -z "$SNAP_BLOCK" ] || [ "${SNAP_BLOCK,,}" == "null" ] || [[ ! $SNAP_BLOCK =~ ^[0-9]+$ ]] ) && \
  SNAP_BLOCK=$(echo $SNAP_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") 
  ( [ -z "$SNAP_BLOCK" ] || [ "${SNAP_BLOCK,,}" == "null" ] || [[ ! $SNAP_BLOCK =~ ^[0-9]+$ ]] ) && \
  SNAP_BLOCK="0"

  if [ $TOP_SNAP_BLOCK -lt $SNAP_BLOCK ] ; then
      TOP_SNAP_BLOCK=$SNAP_BLOCK
  fi
  echo "INFO: Latest Block Height: $TOP_SNAP_BLOCK"

  if [ "${FINISHED_RUNNING,,}" == "true" ] && [ $TOP_SNAP_BLOCK -lt $HALT_HEIGHT ] ; then
      echo "ERROR: Expected node to reach halt height $HALT_HEIGHT but got $TOP_SNAP_BLOCK"
      exit 1
  fi

  # save progress only if status is available or block is diffrent then 0
  if [ $TOP_SNAP_BLOCK -gt 0 ] ; then
    echo "INFO: Updating progress bar..."
    [ $TOP_SNAP_BLOCK -lt $HALT_HEIGHT ] && PERCENTAGE=$(echo "scale=2; ( ( 100 * $TOP_SNAP_BLOCK ) / $HALT_HEIGHT )" | bc)
    [ $TOP_SNAP_BLOCK -ge $HALT_HEIGHT ] && PERCENTAGE="100"
    echo "$PERCENTAGE" > $SNAP_PROGRESS
  fi

  if ps -p "$PID1" > /dev/null ; then
     echo "INFO: Waiting for snapshot node to sync  $TOP_SNAP_BLOCK/$SENTRY_BLOCK..."
     sleep 30
  elif [ ! -z "$PID1" ] ; then
     echo "WARNING: Node finished running, starting tracking and checking final height..."
     kill -2 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P1"
     sleep 5
     kill -15 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P2"
     sleep 10
     kill -9 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1"
     rm -fv $CFG # invalidate all possible connections
     sekaid start --home="$SEKAID_HOME" --trace &> ./output2.log & # launch sekai in state observer mode
     PID1=$!
     sleep 10
     FINISHED_RUNNING="true"
     continue
  fi

  if [ "$TOP_SNAP_BLOCK" -gt "$LAST_SNAP_BLOCK" ] ; then
      echo "INFO: Success, block changed! ($LAST_SNAP_BLOCK -> $TOP_SNAP_BLOCK)"
      LAST_SNAP_BLOCK="$TOP_SNAP_BLOCK"
      i=0
      continue
  fi

  echo "WARNING: Block did not changed! ($LAST_SNAP_BLOCK)"

  if [ "$TOP_SNAP_BLOCK" -lt "$HALT_HEIGHT" ] ; then # restart process if block sync stopped
    if [ $i -ge 4 ] || [ -z "$PID1" ] ; then
        if [ ! -z "$PID1" ] ; then
          echo "WARNING: Block did not changed for the last 2 minutes!"
          echo "INFO: Printing current output log..."
          cat ./output.log | tail -n 100
          kill -2 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P3"
          sleep 5
          kill -15 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P4"
          sleep 10
          kill -9 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1"
        fi

        echo "INFO: Cloning genesis and strarting block sync..."
        cp -f -v -a "$COMMON_CFG" "$CFG" # recover config from common folder
        cp -a -v -f "$COMMON_GENESIS" "$LOCAL_GENESIS" # recover genesis from common folder
        sekaid start --home="$SEKAID_HOME" --halt-height="$HALT_HEIGHT" --trace &> ./output.log || echo "halted" &
        PID1="$!"
        sleep 10
        i=0
    else
        i=$((i + 1))
        echo "INFO: Waiting for block update test $i/4"
    fi
  elif [ "$TOP_SNAP_BLOCK" -ge "$HALT_HEIGHT" ] ; then
      echo "INFO: Snap was compleated, height $TOP_SNAP_BLOCK was reached!"
      break
  fi
done

touch $SNAP_FINALIZYNG

kill -2 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P1"
sleep 5
kill -15 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1 gracefully P2"
sleep 10
kill -9 "$PID1" || echo "INFO: Failed to kill sekai PID $PID1"

echo "INFO: Printing latest output log..."
cat ./output2.log | tail -n 100

echo "INFO: Creating backup package..."
cp "$COMMON_GENESIS" $SEKAID_HOME/data
echo "{\"height\":$HALT_HEIGHT}" > "$SNAP_INFO"

# to prevent appending root path we must zip all from within the target data folder
cd $SEKAID_HOME/data && zip -r "$DESTINATION_FILE" . *

[ ! -f "$DESTINATION_FILE" ] echo "INFO: Failed to create snapshot, file $DESTINATION_FILE was not found" && exit 1

touch $SNAP_DONE
