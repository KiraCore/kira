#!/bin/bash
exec 2>&1
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echo "INFO: Staring snapshoot v0.0.3"

EXECUTED_CHECK="$COMMON_DIR/executed"

SNAP_FILE="$COMMON_DIR/snap.zip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_DIR/genesis.json"

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"

DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

echo "$SNAP_FILENAME" > $SNAP_LATEST

while [ -f "$SNAP_DONE" ] ; do
  echo "INFO: Snapshoot was already finalized, nothing to do here"
  sleep 600
done

while ! ping -c1 sentry &>/dev/null; do
  echo "INFO: Waiting for ping response form sentry node... ($(date))"
  sleep 5
done
echo "INFO: Sentry IP Found: $(getent hosts sentry | awk '{ print $1 }')"

while [ ! -f "$SNAP_FILE" ] && [ ! -f "$COMMON_GENESIS" ]; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id="$NETWORK_NAME" "KIRA SNAPSHOOT NODE" --home=$SEKAID_HOME

  $SELF_CONTAINER/configure.sh

  rm -fv $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  
  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE -d $DATA_DIR
    DATA_GENESIS="$DATA_DIR/genesis.json"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshoot folder, attempting recovery..."
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS # move snapshoot genesis into common folder
    fi

    rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present, starting new sync..."
  fi

  rm -fv $LOCAL_GENESIS
  cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder

  echo "0" > $SNAP_PROGRESS
  touch $EXECUTED_CHECK
fi

touch ./output.log ./output2.log # make sure log files are present so we can cut them
sekaid start --home=$SEKAID_HOME --halt-height="$HALT_HEIGHT" --trace &> ./output.log || echo "halted" &
PID1="$!"

PID_FINISHED="false"
LAST_SNAP_BLOCK=-1
i=0
while : ; do
  echo "INFO: Checking node status..."
  SNAP_STATUS=$(sekaid status 2>&1 | jq -r '.' 2> /dev/null || echo "")
  SNAP_BLOCK=$(echo $SNAP_STATUS | jq -r '.SyncInfo.latest_block_height' 2> /dev/null || echo "") && [ -z "$SNAP_BLOCK" ] && SNAP_BLOCK="0"
  ( [ -z "${SNAP_BLOCK}" ] || [ "${SNAP_BLOCK,,}" == "null" ] ) && SNAP_BLOCK=$(echo $SNAP_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") && [ -z "$SNAP_BLOCK" ] && SNAP_BLOCK="0"

  # sve progress only if status is available or block is diffrent then 0
  [ "$SNAP_BLOCK" != "0" ] && echo $(echo "scale=2; ( ( 100 * $SNAP_BLOCK ) / $HALT_HEIGHT )" | bc) > $SNAP_PROGRESS

  if [ $SNAP_BLOCK -lt $HALT_HEIGHT ] ; then
      echo "INFO: Waiting for snapshoot node to sync $SNAP_BLOCK/$SENTRY_BLOCK..."

      if [ "${PID_FINISHED,,}" == "true" ] ; then
        echo "ERROR: Node finished running but target height was not reached"

        echo "INFO: Output log"
        cat ./output.log | tail -n 100 || echo "WARNINIG: No output log was found!"
        kill -9 $PID1 || echo "INFO: Failed to kill sekai PID $PID1"
        exit 1
      fi
  elif [ $SNAP_BLOCK -ge $HALT_HEIGHT ] ; then
      echo "INFO: Success, target height reached, the node was synced!"
      break
  fi

  if ps -p $PID1 > /dev/null ; then
     echo "INFO: Waiting for node to sync..."
     sleep 30
  else
     echo "WARNING: Node finished running, starting tracking and checking final height..."
     rm -fv $SEKAID_HOME/config/config.toml # invalidate all possible connections
     sekaid start --home=$SEKAID_HOME --trace &> ./output2.log & # launch sekai in state observer mode
     PID1="$?"
     PID_FINISHED="true"
  fi

  if [ "$LAST_SNAP_BLOCK" == "$SNAP_BLOCK" ] ; then # restart process if block sync stopped
    i=$((i + 1))
    if [ $i -ge 4 ] ; then
        echo "WARNING: Block did not changed for the last 2 minutes!"
        echo "INFO: Printing current output log..."
        cat ./output.log | tail -n 100
        kill -9 $PID1 || echo "INFO: Failed to kill sekai PID $PID1"
        sekaid start --home=$SEKAID_HOME --halt-height="$HALT_HEIGHT" --trace &> ./output.log || echo "halted" &
        PID1="$!"
    fi
  else
      echo "INFO: Success, block changed!"
      LAST_SNAP_BLOCK="$SNAP_BLOCK"
      i=0
  fi
done

kill -9 $PID1 || echo "INFO: Failed to kill sekai PID $PID1"

echo "INFO: Printing latest output log..."
cat ./output2.log | tail -n 100

echo "INFO: Creating backup package..."
cp $SEKAID_HOME/config/genesis.json $SEKAID_HOME/data

# to prevent appending root path we must zip all from within the target data folder
cd $SEKAID_HOME/data && zip -r "$DESTINATION_FILE" . *

[ ! -f "$DESTINATION_FILE" ] echo "INFO: Failed to create snapshoot, file $DESTINATION_FILE was not found" && exit 1

touch $SNAP_DONE
