#!/bin/bash

exec 2>&1
set -e
set -x

echo "Building fronted..."
echo "INFO: WORKDIR: $WORKDIR"

cd /root && git clone ${REPO}

cd $WORKDIR

git checkout ${BRANCH}

cat > $WORKDIR/assets/config.json << EOL
{
  "api_url": "http://interx.servicenet.local:11000/api"
}
EOL



if [[ "${ARCHITECTURE,,}" == *"arm"* ]] || [[ "${ARCHITECTURE,,}" == *"aarch"* ]] ; then
    echo "WARNING: Building frontend is not currently supported on ARM architecture"
    mkdir -p ${WORKDIR}/build/web

cat > ${WORKDIR}/build/web/index.html << EOL
<h1>FRONTEND BUILD WITH ARM64 IS NOT SUPPORTED YET, USE X64 ARCHITECTURE</h1>
EOL

else
    flutter pub get
    flutter build web --release
fi


