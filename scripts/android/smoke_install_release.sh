#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

adb_bin="${ADB_BIN:-adb}"
apk_path="${1:-build/app/outputs/flutter-apk/app-release.apk}"
package_name="${ANDROID_APPLICATION_ID:-note.thinkmart.in}"
main_activity="${ANDROID_MAIN_ACTIVITY:-.MainActivity}"

adb_args=()
if [[ -n "${ANDROID_SERIAL:-}" ]]; then
  adb_args+=("-s" "${ANDROID_SERIAL}")
fi

if [[ ! -f "$apk_path" ]]; then
  echo "Release APK not found at $apk_path"
  exit 1
fi

"$adb_bin" "${adb_args[@]}" get-state >/dev/null 2>&1 || {
  echo "No Android emulator or device is available through adb."
  exit 1
}

"$adb_bin" "${adb_args[@]}" install -r "$apk_path"
"$adb_bin" "${adb_args[@]}" shell am start -n "${package_name}/${main_activity}" >/dev/null

printf 'Release smoke install completed for %s.\n' "$apk_path"
printf 'Manual smoke checklist:\n'
printf ' - Sign in with a production-ready test account.\n'
printf ' - Confirm initial sync completes without errors.\n'
printf ' - Permanently delete a note and verify it stays deleted after restart.\n'
printf ' - Run account deletion and confirm the session closes cleanly.\n'