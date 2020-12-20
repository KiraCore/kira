#!/bin/bash

exec 2>&1
set -e

echo $(docker inspect --format="{{.Id}}" "$1" 2> /dev/null || echo "")
