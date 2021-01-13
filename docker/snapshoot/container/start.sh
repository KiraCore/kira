#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."

EXECUTED_CHECK="/root/executed"
HALT_CHECK="${COMMON_DIR}/halt"

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"

DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

while [ -f "$HALT_CHECK" ] || [ -f "$SNAP_DONE" ] ; do
  echo "INFO: Halt file is present or snapshoot was already finalized"
  sleep 30
done

while ! ping -c1 sentry &>/dev/null; do
  echo "INFO: Waiting for ping response form sentry node... ($(date))"
  sleep 5
done
echo "INFO: Validator IP Found: $(getent hosts sentry | awk '{ print $1 }')"

while [ ! -f "$COMMON_DIR/genesis.json" ]; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id=testing testing --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/genesis.json
  rm -fv $SEKAID_HOME/config/config.toml
  rm -fv $SEKAID_HOME/config/node_key.json

  cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/

  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657" --grpc.address="0.0.0.0:9090" --halt-height="$HALT_HEIGHT" --trace &> ./output.log || echo "halted" &
PID1="$!"

PID_FINISHED="false"
while : ; do
  echo "INFO: Checking node status..."
  SNAP_STATUS=$(sekaid status 2> /dev/null | jq -r '.' 2> /dev/null || echo "")
  SNAP_BLOCK=$(echo $SNAP_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") && [ -z "$SNAP_BLOCK" ] && SNAP_BLOCK="0"
  echo $(echo "scale=2; ( ( 100 * $SNAP_BLOCK ) / $HALT_HEIGHT )" | bc) > $SNAP_PROGRESS

  if [ $SNAP_BLOCK -lt $HALT_HEIGHT ] ; then
      echo "INFO: Waiting for snapshoot node to sync $SNAP_BLOCK/$SENTRY_BLOCK..."

      if [ "${PID_FINISHED,,}" == "true" ] ; then
        echo "ERROR: Node finished running but target height was not reached"

        echo "INFO: Output log"
        cat ./output.log | tail -n 100 || echo "WARNINIG: No output log was found!"

        exit 1
      fi
  elif [ $SNAP_BLOCK -ge $HALT_HEIGHT ] ; then
      echo "INFO: Success, target height reached, the node was synced!"
      wait $PID1 || echo "WARNING: Failed to gracefully await shutdown"
      break
  fi

  if ps -p $PID1 > /dev/null ; then
     echo "INFO: Waiting for node to sync..."
     sleep 10
  else
     echo "WARNING: Node finished running, starting tracking and checking final height..."
     rm -fv $SEKAID_HOME/config/config.toml # invalidate all possible connections
     sekaid start --home=$SEKAID_HOME &> ./output2.log & # launch sekai in state observer mode
     PID1="$?"
     PID_FINISHED="true"
  fi
done

kill -9 $PID1 || echo "INFO: Failed to kill sekai PID $PID1"

echo "INFO: Creating backup package..."
cp $SEKAID_HOME/config/genesis.json $SEKAID_HOME/data
zip -r "$DESTINATION_FILE" "$SEKAID_HOME/data"

[ ! -f "$DESTINATION_FILE" ] echo "INFO: Failed to create snapshoot, file $DESTINATION_FILE was not found" && exit 1

touch $SNAP_DONE
