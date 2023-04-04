#!/usr/bin/env bash
set -e
set -x

echo "INFO: Starting package publishing process..."

rm -rfv ./bin
mkdir -p ./bin
zip -r ./bin/kira.zip ./*

cp -fv ./workstation/init.sh ./bin