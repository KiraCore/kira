#!/bin/bash

exec 2>&1
set -e

id=$(docker inspect --format="{{.Id}}" "$1" 2> /dev/null || echo "")
if [ -z "$id" ] || [[ "$id" == *"sha256"* ]] ; then
    echo ""
else
    echo "$id"
fi 
