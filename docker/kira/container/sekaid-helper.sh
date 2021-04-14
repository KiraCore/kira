#!/bin/bash
# QUICK EDIT: FILE="$SELF_CONTAINER/sekaid-helper.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
source $SELF_SCRIPTS/utils.sh

function txAwait() {
    RAW=$(cat)
    TIMEOUT=$1
    START_TIME="$(date -u +%s)"
    (! $(isNaturalNumber)) && TIMEOUT=0

    if (! $(isTxHash "$RAW")) ; then
        # INPUT example: {"height":"0","txhash":"DF8BFCC9730FDBD33AEA184EC3D6C37B4311BC1C0E2296893BC020E4638A0D6F","codespace":"","code":0,"data":"","raw_log":"","logs":[],"info":"","gas_wanted":"0","gas_used":"0","tx":null,"timestamp":""}
        VAL=$(echo $RAW | jsonParse "" 2> /dev/null || echo "")
        if [ -z "$VAL" ] ; then
            echoErr "ERROR: Failed to propagate transaction:"
            echoErr "$RAW"
            exit 1
        fi

        TXHASH=$(echo $VAL | jsonQuickParse "txhash" 2> /dev/null || echo "")
        if [ -z "$VAL" ] ; then
            echoErr "ERROR: Transaction hash 'txhash' was NOT found in the tx propagation response:"
            echoErr "$RAW"
            exit 1
        fi
    else
        TXHASH="${RAW^^}"
    fi

    echoInfo "INFO: Transaction hash '$TXHASH' was found!"
    echoInfo "INFO: Please wait for tx confirmation..."

    while : ; do
        ELAPSED=$(($(date -u +%s) - $START_TIME))
        OUT=$(sekaid query tx $TXHASH --output=json 2> /dev/null | jsonParse "" 2> /dev/null || echo -n "")
        if [ ! -z "$OUT" ] ; then
            echoInfo "INFO: Transaction query response received received:"
            echo $OUT | jq

            CODE=$(echo $OUT | jsonQuickParse "code" 2> /dev/null || echo -n "")
            if [ "$CODE" == "0" ] ; then
                echoInfo "INFO: Transaction was confirmed sucessfully!"
                exit 0
            else
                echoErr "ERROR: Transaction failed with exit code '$CODE'"
                exit 1
            fi
        else
            [ $TIMEOUT -le 0 ] && MAX_TIME="∞" || MAX_TIME="$TIMEOUT"
            echoWarn "WARNING: Transaction was not found, elapsed ${ELAPSED}/${MAX_TIME} s"
        fi

        if [ $TIMEOUT -gt 0 ] && [ $ELAPSED -gt $TIMEOUT ] ; then
            echoInfo "INFO: Transaction query response was NOT received:"
            echo $RAW | jq 2> /dev/null || echoErr "$RAW"
            echoErr "ERROR: Timeout, failed to confirm tx hash '$TXHASH' within ${TIMEOUT} s limit"
            exit 1
        else
            echoInfo "INFO: Please wait for tx confirmation..."
            sleep 5
        fi
    done
}
