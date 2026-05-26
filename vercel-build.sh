#!/usr/bin/env bash
# Vercel build script — runs from the repo root so Vercel finds vercel.json
# without any "Root Directory" tweak in the dashboard. The Flutter project
# itself lives under mobile/, so this script clones the Flutter SDK at the
# repo root, enters mobile/, and runs flutter build web there. The static
# bundle ends up at mobile/build/web, which vercel.json picks up via
# `outputDirectory`.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="$PWD/.flutter-sdk"

echo "──> Setting up Flutter SDK ($FLUTTER_VERSION)..."
if [ -d "$FLUTTER_DIR" ]; then
  echo "    cached SDK found, refreshing"
  (cd "$FLUTTER_DIR" && git fetch --depth 1 origin "$FLUTTER_VERSION" && git reset --hard FETCH_HEAD)
else
  git clone https://github.com/flutter/flutter.git -b "$FLUTTER_VERSION" --depth 1 "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

echo "──> Flutter version"
flutter --version

cd mobile

echo "──> Precaching web artefacts"
flutter precache --web

echo "──> Fetching pub packages"
flutter pub get

echo "──> Building web bundle"
# API_URL is passed in via Vercel env vars; falls back to the default in
# api_client.dart if not set so a local Vercel preview still builds.
API_URL_ARG="${API_URL:-http://10.0.2.2:8000}"
flutter build web --release --dart-define="API_URL=$API_URL_ARG"

echo "──> Done. mobile/build/web contents:"
ls -la build/web | head -20
