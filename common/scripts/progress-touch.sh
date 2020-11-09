#!/bin/bash
set -e

INPUT=$1
NAME=$2
DEBUG=$3

[ "$DEBUG" == "True" ] && set -x
[ -z "$NAME" ] && NAME="default"

ARR=(${INPUT//;/ })
OPERATION=${ARR[0]}
MAX=${ARR[1]}
LEN=${ARR[2]}
PID=${ARR[3]}

[ -z "$OPERATION" ] && OPERATION="+0"
[ -z "${MAX##*[!0-9]*}" ] && MAX=0
[ -z "${LEN##*[!0-9]*}" ] && LEN=0
[ -z "${PID##*[!0-9]*}" ] && PID=0

if [ $PID -ge 1 ] && [ "$NAME" == "default" ] ; then
    COMMAND=$(ps -o cmd fp $PID || echo "")
else
    COMMAND=""
fi

COMMAND=`/bin/echo "$COMMAND" | /usr/bin/md5sum | /bin/cut -f1 -d" "`

PROGRESS_FILE="/tmp/progress_$NAME"
LOADER_FILE="/tmp/loader_$NAME"
PROGRESS_TIME=0
TIME_FILE="${PROGRESS_FILE}_time"
SPAN_FILE="${PROGRESS_FILE}_${COMMAND}" # containes avg elapsed time from the previous run

touch $PROGRESS_FILE
touch $TIME_FILE
touch $SPAN_FILE

VALUE=$(cat $PROGRESS_FILE || echo "0")
[ -z "${VALUE##*[!0-9]*}" ] && VALUE=0
if [ $MAX -gt 0 ] ; then
    let "PERCENTAGE_OLD=(100*$VALUE)/$MAX" || PERCENTAGE_OLD=0
else
    PERCENTAGE_OLD=0
fi

SPAN=$(cat $SPAN_FILE || echo "0")
[ -z "${SPAN##*[!0-9]*}" ] && SPAN=0
[ $SPAN -le 0 ] && SPAN=3000
[ $SPAN -gt 9000 ] && SPAN=3000

let "RESULT=${VALUE}${OPERATION}" || RESULT=0
echo "$RESULT" > $PROGRESS_FILE || echo "ERROR: Failed to save result into progress file `$PROGRESS_FILE`"

TIME_START="$(date -u +%s)"
if [ ! -f $TIME_FILE ] || [ $RESULT -eq 0 ] ; then
    echo "$TIME_START" > $TIME_FILE || echo "ERROR: Failed to save time into progress time file `$TIME_FILE`"
    echo "0" > $LOADER_FILE || echo "ERROR: Failed to save progress to loader file `$LOADER_FILE`"
    PERCENTAGE_OLD=0
fi

[ $MAX -le 0 ] && exit 0
LAST_SPEED=140
while : ; do
    RESULT=$(cat $PROGRESS_FILE || echo "0")
    [ -z "${RESULT##*[!0-9]*}" ] && RESULT=0

    TIME_NOW="$(date -u +%s)"
    TIME_START=$(cat $TIME_FILE || echo $TIME_NOW)
    [ -z "${TIME_START##*[!0-9]*}" ] && TIME_START=$TIME_NOW
    ELAPSED=$((${TIME_NOW}-${TIME_START}))

    let "PERCENTAGE=(100*$RESULT)/$MAX" || PERCENTAGE=0
    [ $PERCENTAGE -gt 100 ] && PERCENTAGE=100
    [ $PERCENTAGE -lt 0 ] && PERCENTAGE=0

    let "SPAN_PERCENTAGE=(100*$ELAPSED)/$SPAN" || SPAN_PERCENTAGE=$PERCENTAGE
    [ $SPAN_PERCENTAGE -gt 100 ] && SPAN_PERCENTAGE=100
    [ $SPAN_PERCENTAGE -lt 0 ] && SPAN_PERCENTAGE=0

    let "AVG_PERCENTAGE=((9*$PERCENTAGE)+$SPAN_PERCENTAGE)/10" || AVG_PERCENTAGE=0
    [ $AVG_PERCENTAGE -gt 100 ] && AVG_PERCENTAGE=100
    [ $AVG_PERCENTAGE -lt 0 ] && AVG_PERCENTAGE=0
    [ $AVG_PERCENTAGE -gt 1 ] && PERCENTAGE=$AVG_PERCENTAGE

    OLD_PERCENTAGE=$(cat $LOADER_FILE || echo "0")
    [ -z "${OLD_PERCENTAGE##*[!0-9]*}" ] && OLD_PERCENTAGE=0
    [ $OLD_PERCENTAGE -gt $PERCENTAGE ] && PERCENTAGE=$OLD_PERCENTAGE

    echo "$AVG_PERCENTAGE" > $LOADER_FILE || echo "ERROR: Failed to save progress to loader file `$LOADER_FILE`"
    [ $LEN -le 0 ] && printf "%s%%" "${PERCENTAGE}" && break

    [ "$PID" != "0" ] && if ps -p $PID > /dev/null ; then 
        [ $PERCENTAGE -ge 100 ] && PERCENTAGE=99
        CONTINUE="True"
    else
        [ $RESULT -ge $MAX ] && PERCENTAGE=100
        CONTINUE="False"
    fi

    [ $PERCENTAGE_OLD -gt $PERCENTAGE ] && PERCENTAGE_OLD=$PERCENTAGE
    let "DELTA_PERCENTAGE=$PERCENTAGE-$PERCENTAGE_OLD" || DELTA_PERCENTAGE=0
    let "PROGRESS_SPEED=($LAST_SPEED+(1000/(7*($DELTA_PERCENTAGE+1))))/2" || PROGRESS_SPEED=0
    LAST_SPEED=$PROGRESS_SPEED # simulate acceleraton
    [ $PROGRESS_SPEED -lt 20 ] && PROGRESS_SPEED=20
    [ $PROGRESS_SPEED -lt 100 ] && PROGRESS_SPEED="0$PROGRESS_SPEED"
    PROGRESS_SPEED="0.$PROGRESS_SPEED"

    for ((i=$PERCENTAGE_OLD;i<=$PERCENTAGE;i++)); do
        let "COUNT_BLACK=($LEN*$i)/100" || COUNT_BLACK=0
        [ $COUNT_BLACK -lt 0 ] && COUNT_BLACK=0
        [ $COUNT_BLACK -gt $LEN ] && COUNT_BLACK=$LEN
        let "COUNT_WHITE=$LEN-$COUNT_BLACK" || COUNT_WHITE=0
        [ $COUNT_WHITE -gt $LEN ] && COUNT_WHITE=$LEN
        if [ $COUNT_BLACK -gt 0 ] ; then let "COUNT_BLACK=$COUNT_BLACK-1" || COUNT_BLACK=0 ; fi
        if [ $COUNT_WHITE -ge $LEN ] ; then let "COUNT_WHITE=$COUNT_WHITE-1" ; fi
        
        BLACK=$(printf "%${COUNT_BLACK}s" | tr " " "#")
        WHITE=$(printf "%${COUNT_WHITE}s" | tr " " ".")

        TIME_NOW="$(date -u +%s)"
        ELAPSED=$((${TIME_NOW}-${TIME_START}))
         
        echo -ne "\r$BLACK-$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK\\$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK|$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK/$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK-$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK\\$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
        echo -ne "\r$BLACK|$WHITE ($i%|${ELAPSED}s)" && sleep $PROGRESS_SPEED
    done
     
    PERCENTAGE_OLD=$PERCENTAGE
    [ "$CONTINUE" == "True" ] && continue
    
    if [ "$PID" != "0" ] && [ $PERCENTAGE -eq 100 ] ; then
        echo -ne "\r${BLACK}${WHITE} ($PERCENTAGE%|${ELAPSED}s|${RESULT}/${MAX})"
        let "SPAN_AVG=($ELAPSED+$SPAN)/2" || SPAN_AVG=0
        echo "$SPAN_AVG" > $SPAN_FILE  || echo "WARNING: Failed to update span file `$SPAN_FILE`"
    else
        echo -ne "\r${BLACK}${WHITE} ($PERCENTAGE%|${ELAPSED}s)"
    fi

    break
done
