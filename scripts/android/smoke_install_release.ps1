Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$adbBin = if ($env:ADB_BIN) { $env:ADB_BIN } else { 'adb' }
$apkPath = if ($args.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($args[0])) {
  $args[0]
} else {
  'build\app\outputs\flutter-apk\app-release.apk'
}
$packageName = if ($env:ANDROID_APPLICATION_ID) {
  $env:ANDROID_APPLICATION_ID
} else {
  'note.thinkmart.in'
}
$mainActivity = if ($env:ANDROID_MAIN_ACTIVITY) {
  $env:ANDROID_MAIN_ACTIVITY
} else {
  '.MainActivity'
}

if (-not (Test-Path $apkPath)) {
  Write-Host "Release APK not found at $apkPath"
  exit 1
}

$adbArgs = @()
if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SERIAL)) {
  $adbArgs += @('-s', $env:ANDROID_SERIAL)
}

& $adbBin @adbArgs get-state *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host 'No Android emulator or device is available through adb.'
  exit 1
}

& $adbBin @adbArgs install -r $apkPath
& $adbBin @adbArgs shell am start -n "$packageName/$mainActivity" *> $null

Write-Host "Release smoke install completed for $apkPath."
Write-Host 'Manual smoke checklist:'
Write-Host ' - Sign in with a production-ready test account.'
Write-Host ' - Confirm initial sync completes without errors.'
Write-Host ' - Permanently delete a note and verify it stays deleted after restart.'
Write-Host ' - Run account deletion and confirm the session closes cleanly.'