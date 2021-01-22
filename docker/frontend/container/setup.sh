#!/bin/bash

exec 2>&1
set -e
set -x

echo "Building fronted..."
FRONTEND_SRC="/root/kira-frontend/src"
echo "INFO: WORKDIR: $FRONTEND_SRC"

cd /root && git clone ${REPO}

cd $FRONTEND_SRC

git checkout ${BRANCH}

cat > $FRONTEND_SRC/assets/config.json << EOL
{
  "api_url": "http://interx.servicenet.local:11000/api"
}
EOL

flutter pub get
flutter build web --release

#ARCHITECTURE=$(uname -m)
#
#if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
#    echo "WARNING: Building frontend is not currently supported on ARM architecture"
#    mkdir -p ${FRONTEND_SRC}/build/web
#
#cat > ${FRONTEND_SRC}/build/web/index.html << EOL
#<!DOCTYPE html>
#<html>
#<head>
#</head>
#<body>
#<h1>FRONTEND BUILD WITH ARM64 IS NOT SUPPORTED YET, USE X64 ARCHITECTURE</h1>
#</body>
#</html>
#EOL
#
#else
#    flutter pub get
#    flutter build web --release
#fi


