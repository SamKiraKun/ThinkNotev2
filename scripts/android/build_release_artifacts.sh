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
: "${ENABLE_EXPERIMENTAL_SYNC:=false}"

if [[ "${ENABLE_EXPERIMENTAL_SYNC}" == "true" ]]; then
  required_sync_env=(
    API_URL
    FIREBASE_API_KEY
    FIREBASE_APP_ID
    FIREBASE_MESSAGING_SENDER_ID
    FIREBASE_PROJECT_ID
  )

  for var_name in "${required_sync_env[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
      echo "Missing required experimental sync environment variable: ${var_name}"
      exit 1
    fi
  done

  if [[ "${APP_FLAVOR}" == "production" && "${API_URL}" != https://* ]]; then
    echo "Production experimental sync builds must use an HTTPS API_URL."
    exit 1
  fi
fi

build_args=(
  "--release"
  "--build-number=${CIRCLE_BUILD_NUM:-1}"
  "--dart-define=APP_FLAVOR=${APP_FLAVOR}"
  "--dart-define=ENABLE_ANALYTICS=${ENABLE_ANALYTICS}"
  "--dart-define=ENABLE_EXPERIMENTAL_SYNC=${ENABLE_EXPERIMENTAL_SYNC}"
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

printf '{\n  "git_sha": "%s",\n  "circle_build_num": "%s",\n  "app_flavor": "%s",\n  "enable_analytics": "%s",\n  "enable_experimental_sync": "%s",\n  "target_sdk": "%s",\n  "play_artifact": "%s",\n  "qa_artifact": "%s",\n  "r8_mapping": "%s"\n}\n' \
  "${CIRCLE_SHA1:-$(git rev-parse HEAD)}" \
  "${CIRCLE_BUILD_NUM:-1}" \
  "${APP_FLAVOR}" \
  "${ENABLE_ANALYTICS}" \
  "${ENABLE_EXPERIMENTAL_SYNC}" \
  "${target_sdk:-unknown}" \
  "build/app/outputs/bundle/release/app-release.aab" \
  "build/app/outputs/flutter-apk/app-release.apk" \
  "build/release-metadata/r8-mapping.txt" \
  > build/release-metadata/release-manifest.json