#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

flutter_bin="${FLUTTER_BIN:-flutter}"

if [[ -z "${APP_FLAVOR:-}" ]]; then
  echo "Missing required runtime environment variable: APP_FLAVOR"
  exit 1
fi

case "${APP_FLAVOR}" in
  development|staging|production) ;;
  *)
    echo "APP_FLAVOR must be one of: development, staging, production"
    exit 1
    ;;
esac

: "${ENABLE_ANALYTICS:=false}"
: "${API_URL:=https://api.unicef.edu.eu.org}"
: "${FIREBASE_ANDROID_APP_ID:=${FIREBASE_APP_ID:-}}"

required_sync_env=(
  FIREBASE_API_KEY
  FIREBASE_ANDROID_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
)

for var_name in "${required_sync_env[@]}"; do
  if [[ -z "${!var_name:-}" ]]; then
    echo "Missing required authenticated build environment variable: ${var_name}"
    exit 1
  fi
done

canonical_api_url="https://api.unicef.edu.eu.org"
normalized_api_url="${API_URL%/}"
if [[ "${APP_FLAVOR}" == "production" && "${normalized_api_url}" != "${canonical_api_url}" ]]; then
  echo "Production authenticated builds must use API_URL=${canonical_api_url}."
  echo "Do not ship production builds pointed at localhost, Render, staging, or placeholder endpoints."
  exit 1
fi

build_args=(
  "--release"
  "--build-number=${CIRCLE_BUILD_NUM:-1}"
  "--dart-define=APP_FLAVOR=${APP_FLAVOR}"
  "--dart-define=ENABLE_ANALYTICS=${ENABLE_ANALYTICS}"
)

append_optional_define() {
  local key="$1"
  local value="${!key:-}"

  if [[ -n "$value" ]]; then
    build_args+=("--dart-define=${key}=${value}")
  fi
}

append_optional_define "API_URL"
append_optional_define "FIREBASE_API_KEY"
append_optional_define "FIREBASE_APP_ID"
append_optional_define "FIREBASE_ANDROID_APP_ID"
append_optional_define "FIREBASE_MESSAGING_SENDER_ID"
append_optional_define "FIREBASE_PROJECT_ID"
append_optional_define "FIREBASE_DATABASE_URL"
append_optional_define "FIREBASE_STORAGE_BUCKET"
append_optional_define "SENTRY_DSN"
append_optional_define "ANALYTICS_KEY"

"$flutter_bin" build apk "${build_args[@]}"
"$flutter_bin" build appbundle "${build_args[@]}"

mkdir -p build/release-metadata
"$flutter_bin" --version > build/release-metadata/flutter-version.txt
(cd android && ./gradlew --version) > build/release-metadata/gradle-version.txt

cp pubspec.lock build/release-metadata/pubspec.lock
cp android/gradle/wrapper/gradle-wrapper.properties build/release-metadata/gradle-wrapper.properties
cp android/build.gradle.kts build/release-metadata/android-build.gradle.kts
cp android/app/build.gradle.kts build/release-metadata/android-app-build.gradle.kts

if [[ -f backend/package-lock.json ]]; then
  cp backend/package-lock.json build/release-metadata/backend-package-lock.json
fi

if [[ -f build/app/outputs/mapping/release/mapping.txt ]]; then
  cp build/app/outputs/mapping/release/mapping.txt build/release-metadata/r8-mapping.txt
else
  printf 'R8 mapping file was not generated for this build.\n' > build/release-metadata/r8-mapping.txt
fi

target_sdk="$(grep -E 'targetSdk = [0-9]+' android/app/build.gradle.kts | head -n1 | sed -E 's/.*targetSdk = ([0-9]+).*/\1/')"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum \
    build/app/outputs/bundle/release/app-release.aab \
    build/app/outputs/flutter-apk/app-release.apk \
    > build/release-metadata/artifact-sha256.txt
fi

printf '{\n  "git_sha": "%s",\n  "circle_build_num": "%s",\n  "app_flavor": "%s",\n  "enable_analytics": "%s",\n  "sync_mode": "%s",\n  "target_sdk": "%s",\n  "play_artifact": "%s",\n  "qa_artifact": "%s",\n  "r8_mapping": "%s",\n  "api_url": "%s"\n}\n' \
  "${CIRCLE_SHA1:-$(git rev-parse HEAD)}" \
  "${CIRCLE_BUILD_NUM:-1}" \
  "${APP_FLAVOR}" \
  "${ENABLE_ANALYTICS}" \
  "enabled" \
  "${target_sdk:-unknown}" \
  "build/app/outputs/bundle/release/app-release.aab" \
  "build/app/outputs/flutter-apk/app-release.apk" \
  "build/release-metadata/r8-mapping.txt" \
  "${normalized_api_url}" \
  > build/release-metadata/release-manifest.json
