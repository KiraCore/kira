#!/bin/bash

exec 2>&1
set -e

echo $(docker ps --no-trunc -aqf name="$1" 2> /dev/null || echo "")
