#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring frontend..."

cd /root/kira-frontend/src
flutter pub get

# flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
flutter build web

mv /root/default /etc/nginx/sites-enabled

nginx -t

service nginx restart

cd /root/kira-frontend/src/web
ls

cat /etc/nginx/sites-enabled/default
