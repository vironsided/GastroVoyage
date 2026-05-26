#!/usr/bin/env bash
# Vercel build script — clones Flutter SDK (cached between builds by Vercel),
# runs `flutter build web`, and writes the static bundle to `build/web` which
# vercel.json picks up via `outputDirectory`.
#
# Vercel's installCommand and buildCommand each run in their own shell, so
# anything set in install (PATH, etc.) is lost by the time build runs. Putting
# everything into a single script avoids that footgun.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="$PWD/.flutter-sdk"

echo "──> Setting up Flutter SDK ($FLUTTER_VERSION)..."
if [ -d "$FLUTTER_DIR" ]; then
  echo "    cached SDK found, pulling latest"
  (cd "$FLUTTER_DIR" && git fetch --depth 1 origin "$FLUTTER_VERSION" && git reset --hard FETCH_HEAD)
else
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

echo "──> Flutter version"
flutter --version

echo "──> Precaching web artefacts"
flutter precache --web

echo "──> Fetching pub packages"
flutter pub get

echo "──> Building web bundle"
# API_URL is passed in via Vercel env vars; falls back to the default in
# api_client.dart if not set so a local Vercel preview still builds.
API_URL_ARG="${API_URL:-http://10.0.2.2:8000}"
flutter build web --release --dart-define="API_URL=$API_URL_ARG"

echo "──> Done. build/web contents:"
ls -la build/web | head -20
