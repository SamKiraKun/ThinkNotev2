Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$sourceAabPath = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
$sourceApkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'
$aabPath = Join-Path $repoRoot 'build\release-artifacts\ThinkNote-release.aab'
$apkPath = Join-Path $repoRoot 'build\release-artifacts\ThinkNote-qa-release.apk'

function Require-Artifact {
  param(
    [string]$Path,
    [string]$ExpectedExtension
  )

  if (-not (Test-Path $Path)) {
    Write-Host "Release artifact not found: $Path"
    Write-Host 'Available build outputs:'
    Get-ChildItem -Recurse -File (Join-Path $repoRoot 'build\app\outputs'), (Join-Path $repoRoot 'build\release-artifacts') -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    exit 1
  }

  if ((Get-Item $Path).Length -le 0) {
    Write-Host "Release artifact is empty: $Path"
    exit 1
  }

  if ([System.IO.Path]::GetExtension($Path).TrimStart('.').ToLowerInvariant() -ne $ExpectedExtension.ToLowerInvariant()) {
    Write-Host "Release artifact does not use the expected .$ExpectedExtension extension: $Path"
    exit 1
  }
}

Require-Artifact -Path $sourceAabPath -ExpectedExtension 'aab'
Require-Artifact -Path $sourceApkPath -ExpectedExtension 'apk'
Require-Artifact -Path $aabPath -ExpectedExtension 'aab'
Require-Artifact -Path $apkPath -ExpectedExtension 'apk'

if (-not ((Get-FileHash -Algorithm SHA256 -Path $sourceAabPath).Hash -eq (Get-FileHash -Algorithm SHA256 -Path $aabPath).Hash)) {
  Write-Host 'Staged Play bundle does not match the generated build output.'
  exit 1
}

if (-not ((Get-FileHash -Algorithm SHA256 -Path $sourceApkPath).Hash -eq (Get-FileHash -Algorithm SHA256 -Path $apkPath).Hash)) {
  Write-Host 'Staged QA APK does not match the generated build output.'
  exit 1
}

$metadataDir = Join-Path $repoRoot 'build\release-metadata'
New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null

@(
  "Artifact: $aabPath"
  (Get-Item $aabPath | Format-List FullName,Length,LastWriteTime | Out-String).Trim()
) | Set-Content -Path (Join-Path $metadataDir 'aab-file-info.txt')

@(
  "Artifact: $apkPath"
  (Get-Item $apkPath | Format-List FullName,Length,LastWriteTime | Out-String).Trim()
) | Set-Content -Path (Join-Path $metadataDir 'apk-file-info.txt')

& jarsigner -verify -verbose -certs $aabPath | Set-Content -Path (Join-Path $metadataDir 'aab-signature-verification.txt')
& jarsigner -verify -verbose -certs $apkPath | Set-Content -Path (Join-Path $metadataDir 'apk-signature-verification.txt')

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ZipArchive {
  param(
    [string]$Path,
    [string]$OutputPath,
    [string[]]$RequiredEntries = @()
  )

  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $entryNames = @()
    foreach ($entry in $archive.Entries) {
      $entryNames += $entry.FullName
    }

    foreach ($requiredEntry in $RequiredEntries) {
      if ($requiredEntry -notin $entryNames) {
        throw "Archive is missing required entry: $requiredEntry"
      }
    }
  } finally {
    $archive.Dispose()
  }

  $entryNames | Set-Content -Path $OutputPath
}

Test-ZipArchive -Path $aabPath -OutputPath (Join-Path $metadataDir 'aab-contents.txt') -RequiredEntries @(
  'BundleConfig.pb',
  'base/manifest/AndroidManifest.xml'
)
Test-ZipArchive -Path $apkPath -OutputPath (Join-Path $metadataDir 'apk-zip-validation.txt')
'Archive structure verified.' | Set-Content -Path (Join-Path $metadataDir 'aab-zip-validation.txt')
