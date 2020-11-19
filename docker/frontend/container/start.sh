#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring frontend..."
flutter pub get

flutter run -d chrome --dart-define=FLUTTER_WEB_USE_SKIA=true
flutter run -d web --dart-define=FLUTTER_WEB_USE_SKIA=true
