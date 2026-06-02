#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source_aab_path="build/app/outputs/bundle/release/app-release.aab"
source_apk_path="build/app/outputs/flutter-apk/app-release.apk"
aab_path="build/release-artifacts/ThinkNote-release.aab"
apk_path="build/release-artifacts/ThinkNote-qa-release.apk"

require_artifact() {
  local artifact_path="$1"
  local expected_extension="$2"

  if [[ ! -f "$artifact_path" ]]; then
    echo "ERROR: Release artifact not found at $artifact_path"
    echo "Available build outputs:"
    find build/app/outputs build/release-artifacts -type f | sort || true
    exit 1
  fi

  if [[ ! -s "$artifact_path" ]]; then
    echo "ERROR: Release artifact exists but is empty: $artifact_path"
    exit 1
  fi

  if [[ "$artifact_path" != *".${expected_extension}" ]]; then
    echo "ERROR: Release artifact does not use the expected .${expected_extension} extension: $artifact_path"
    exit 1
  fi
}

require_artifact "$source_aab_path" "aab"
require_artifact "$source_apk_path" "apk"
require_artifact "$aab_path" "aab"
require_artifact "$apk_path" "apk"

cmp -s "$source_aab_path" "$aab_path" || {
  echo "ERROR: Staged Play bundle does not match the generated build output."
  exit 1
}

cmp -s "$source_apk_path" "$apk_path" || {
  echo "ERROR: Staged QA APK does not match the generated build output."
  exit 1
}

mkdir -p build/release-metadata

{
  echo "Artifact: $aab_path"
  ls -lh "$aab_path"
  if command -v file >/dev/null 2>&1; then
    file "$aab_path" || true
  fi
} > build/release-metadata/aab-file-info.txt

{
  echo "Artifact: $apk_path"
  ls -lh "$apk_path"
  if command -v file >/dev/null 2>&1; then
    file "$apk_path" || true
  fi
} > build/release-metadata/apk-file-info.txt

jarsigner -verify -verbose -certs "$aab_path" \
  > build/release-metadata/aab-signature-verification.txt
jarsigner -verify -verbose -certs "$apk_path" \
  > build/release-metadata/apk-signature-verification.txt
unzip -tqq "$aab_path" > build/release-metadata/aab-zip-validation.txt
unzip -tqq "$apk_path" > build/release-metadata/apk-zip-validation.txt
unzip -l "$aab_path" > build/release-metadata/aab-contents.txt

grep -q 'BundleConfig\.pb' build/release-metadata/aab-contents.txt || {
  echo "ERROR: Generated AAB is missing BundleConfig.pb."
  exit 1
}

grep -q 'base/manifest/AndroidManifest\.xml' build/release-metadata/aab-contents.txt || {
  echo "ERROR: Generated AAB is missing the base module AndroidManifest.xml."
  exit 1
}
