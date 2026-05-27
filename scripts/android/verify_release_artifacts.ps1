Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$aabPath = Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab'
$apkPath = Join-Path $repoRoot 'build\app\outputs\flutter-apk\app-release.apk'

foreach ($artifactPath in @($apkPath, $aabPath)) {
  if (-not (Test-Path $artifactPath)) {
    Write-Host "Release artifact not found: $artifactPath"
    exit 1
  }
}

$metadataDir = Join-Path $repoRoot 'build\release-metadata'
New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null

& jarsigner -verify -verbose -certs $aabPath | Set-Content -Path (Join-Path $metadataDir 'aab-signature-verification.txt')
& jarsigner -verify -verbose -certs $apkPath | Set-Content -Path (Join-Path $metadataDir 'apk-signature-verification.txt')

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Test-ZipArchive {
  param(
    [string]$Path,
    [string]$OutputPath
  )

  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    foreach ($entry in $archive.Entries) {
      $null = $entry.FullName
    }
  } finally {
    $archive.Dispose()
  }

  'Archive structure verified.' | Set-Content -Path $OutputPath
}

Test-ZipArchive -Path $aabPath -OutputPath (Join-Path $metadataDir 'aab-zip-validation.txt')
Test-ZipArchive -Path $apkPath -OutputPath (Join-Path $metadataDir 'apk-zip-validation.txt')