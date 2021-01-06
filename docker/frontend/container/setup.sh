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

flutter pub get
flutter build web --release