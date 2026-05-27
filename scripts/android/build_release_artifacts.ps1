Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$flutterBin = if ($env:FLUTTER_BIN) {
  $env:FLUTTER_BIN
} elseif (Test-Path 'C:\src\flutter\bin\flutter.bat') {
  'C:\src\flutter\bin\flutter.bat'
} else {
  'flutter'
}

if ([string]::IsNullOrWhiteSpace($env:APP_FLAVOR)) {
  Write-Host 'Missing required runtime environment variable: APP_FLAVOR'
  exit 1
}

$appFlavor = $env:APP_FLAVOR.Trim()
if ($appFlavor -notin @('development', 'staging', 'production')) {
  Write-Host 'APP_FLAVOR must be one of: development, staging, production'
  exit 1
}

$enableAnalytics = if ([string]::IsNullOrWhiteSpace($env:ENABLE_ANALYTICS)) {
  'false'
} else {
  $env:ENABLE_ANALYTICS
}

$enableExperimentalSync = if ([string]::IsNullOrWhiteSpace($env:ENABLE_EXPERIMENTAL_SYNC)) {
  'false'
} else {
  $env:ENABLE_EXPERIMENTAL_SYNC
}

if ($enableExperimentalSync -eq 'true') {
  foreach ($requiredVar in @(
    'API_URL',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID'
  )) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($requiredVar))) {
      Write-Host "Missing required experimental sync environment variable: $requiredVar"
      exit 1
    }
  }

  if ($appFlavor -eq 'production' -and -not $env:API_URL.StartsWith('https://')) {
    Write-Host 'Production experimental sync builds must use an HTTPS API_URL.'
    exit 1
  }
}

$buildNumber = if ([string]::IsNullOrWhiteSpace($env:CIRCLE_BUILD_NUM)) {
  '1'
} else {
  $env:CIRCLE_BUILD_NUM
}

$buildArgs = @(
  '--release',
  "--build-number=$buildNumber",
  "--dart-define=APP_FLAVOR=$appFlavor",
  "--dart-define=ENABLE_ANALYTICS=$enableAnalytics",
  "--dart-define=ENABLE_EXPERIMENTAL_SYNC=$enableExperimentalSync"
)

function Add-OptionalDefine {
  param([string]$Name)

  $value = [Environment]::GetEnvironmentVariable($Name)
  if (-not [string]::IsNullOrWhiteSpace($value)) {
    $script:buildArgs += "--dart-define=$Name=$value"
  }
}

foreach ($optionalVar in @(
  'API_URL',
  'FIREBASE_API_KEY',
  'FIREBASE_APP_ID',
  'FIREBASE_MESSAGING_SENDER_ID',
  'FIREBASE_PROJECT_ID',
  'FIREBASE_DATABASE_URL',
  'FIREBASE_STORAGE_BUCKET',
  'SENTRY_DSN',
  'ANALYTICS_KEY'
)) {
  Add-OptionalDefine -Name $optionalVar
}

& $flutterBin build apk @buildArgs
& $flutterBin build appbundle @buildArgs

$metadataDir = Join-Path $repoRoot 'build\release-metadata'
New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null

(& $flutterBin --version) | Set-Content -Path (Join-Path $metadataDir 'flutter-version.txt')

Push-Location (Join-Path $repoRoot 'android')
try {
  (& .\gradlew.bat --version) | Set-Content -Path (Join-Path $metadataDir 'gradle-version.txt')
} finally {
  Pop-Location
}

Copy-Item -Path (Join-Path $repoRoot 'pubspec.lock') -Destination (Join-Path $metadataDir 'pubspec.lock') -Force
Copy-Item -Path (Join-Path $repoRoot 'android\gradle\wrapper\gradle-wrapper.properties') -Destination (Join-Path $metadataDir 'gradle-wrapper.properties') -Force
Copy-Item -Path (Join-Path $repoRoot 'android\build.gradle.kts') -Destination (Join-Path $metadataDir 'android-build.gradle.kts') -Force
Copy-Item -Path (Join-Path $repoRoot 'android\app\build.gradle.kts') -Destination (Join-Path $metadataDir 'android-app-build.gradle.kts') -Force

$backendLockfile = Join-Path $repoRoot 'backend\package-lock.json'
if (Test-Path $backendLockfile) {
  Copy-Item -Path $backendLockfile -Destination (Join-Path $metadataDir 'backend-package-lock.json') -Force
}

$mappingSource = Join-Path $repoRoot 'build\app\outputs\mapping\release\mapping.txt'
$mappingDestination = Join-Path $metadataDir 'r8-mapping.txt'
if (Test-Path $mappingSource) {
  Copy-Item -Path $mappingSource -Destination $mappingDestination -Force
} else {
  'R8 mapping file was not generated for this build.' | Set-Content -Path $mappingDestination
}

$targetSdkMatch = Select-String -Path (Join-Path $repoRoot 'android\app\build.gradle.kts') -Pattern 'targetSdk = ([0-9]+)' | Select-Object -First 1
$targetSdk = if ($targetSdkMatch -and $targetSdkMatch.Matches.Count -gt 0) {
  $targetSdkMatch.Matches[0].Groups[1].Value
} else {
  'unknown'
}

$artifactHashes = foreach ($artifactPath in @(
  (Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'),
  (Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk')
)) {
  $hash = (Get-FileHash -Algorithm SHA256 -Path $artifactPath).Hash.ToLowerInvariant()
  $relativePath = [System.IO.Path]::GetRelativePath($repoRoot, $artifactPath).Replace('\', '/')
  "$hash *$relativePath"
}
$artifactHashes | Set-Content -Path (Join-Path $metadataDir 'artifact-sha256.txt')

$gitSha = if ([string]::IsNullOrWhiteSpace($env:CIRCLE_SHA1)) {
  (& git rev-parse HEAD).Trim()
} else {
  $env:CIRCLE_SHA1
}

$manifest = [ordered]@{
  git_sha = $gitSha
  circle_build_num = $buildNumber
  app_flavor = $appFlavor
  enable_analytics = $enableAnalytics
  enable_experimental_sync = $enableExperimentalSync
  target_sdk = $targetSdk
  play_artifact = 'build/app/outputs/bundle/release/app-release.aab'
  qa_artifact = 'build/app/outputs/flutter-apk/app-release.apk'
  r8_mapping = 'build/release-metadata/r8-mapping.txt'
}
$manifest | ConvertTo-Json | Set-Content -Path (Join-Path $metadataDir 'release-manifest.json')