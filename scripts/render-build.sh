#!/usr/bin/env bash
#
# Render build step: install the Flutter SDK, compile the web app, and leave
# the result in swift-fleet-api/public/ where server.js serves it from.
#
# Run by render.yaml as:
#   bash scripts/render-build.sh
#
# Set FLUTTER_VERSION to pin a release (recommended once you know a good one);
# it defaults to the stable channel.
#
# NOTE: `flutter build web` needs roughly 2 GB of RAM. On Render's free tier
# (512 MB) this can be killed mid-build. If that happens, use the prebuilt
# path in DEPLOY.md instead — build locally, commit swift-fleet-api/public/,
# and switch the build command to `npm install --omit=dev`.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_DIR="${HOME}/flutter"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/swift-fleet-api/public"

echo "==> Swift Fleet build"
echo "    project root : ${PROJECT_ROOT}"
echo "    flutter      : ${FLUTTER_VERSION}"
echo "    output       : ${OUTPUT_DIR}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Cloning Flutter (${FLUTTER_VERSION})"
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
else
  echo "==> Reusing cached Flutter SDK"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get

echo "==> Compiling web release bundle"
flutter build web --release --output "${OUTPUT_DIR}"

for required in index.html main.dart.js; do
  if [ ! -f "${OUTPUT_DIR}/${required}" ]; then
    echo "✖ build finished but ${required} is missing from public/" >&2
    exit 1
  fi
done

echo "✔ Flutter web bundle ready in ${OUTPUT_DIR}"
