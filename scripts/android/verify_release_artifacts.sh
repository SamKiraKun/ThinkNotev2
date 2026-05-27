#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

aab_path="build/app/outputs/bundle/release/app-release.aab"
apk_path="build/app/outputs/flutter-apk/app-release.apk"

test -f "$apk_path"
test -f "$aab_path"

mkdir -p build/release-metadata

jarsigner -verify -verbose -certs "$aab_path" \
  > build/release-metadata/aab-signature-verification.txt
jarsigner -verify -verbose -certs "$apk_path" \
  > build/release-metadata/apk-signature-verification.txt
unzip -tqq "$aab_path" > build/release-metadata/aab-zip-validation.txt
unzip -tqq "$apk_path" > build/release-metadata/apk-zip-validation.txt