$ErrorActionPreference = "Stop"

# Live Desk renders approved macOS screen streams with flutter_webrtc. Keep the
# native plugin registered; an installer without it would show only a blank UI.
$dependenciesFile = Join-Path $PSScriptRoot ".flutter-plugins-dependencies"
$packageConfig = Join-Path $PSScriptRoot ".dart_tool\package_config.json"
if (-not (Test-Path -LiteralPath $packageConfig)) {
  throw "Dart package metadata was not found: $packageConfig. Run flutter pub get first."
}

# Older builds removed this declaration from the shared Pub cache. Restore it
# before regenerating plugins so a developer does not need `flutter pub cache
# repair`, and clean GitHub runners continue to work unchanged.
$config = Get-Content -LiteralPath $packageConfig -Raw | ConvertFrom-Json
$webrtcPackage = @($config.packages) | Where-Object { $_.name -eq "flutter_webrtc" } | Select-Object -First 1
if (-not $webrtcPackage) {
  throw "flutter_webrtc is not in the resolved package configuration."
}
$pluginManifest = Join-Path ([Uri]$webrtcPackage.rootUri).LocalPath "pubspec.yaml"
if (-not (Test-Path -LiteralPath $pluginManifest)) {
  throw "flutter_webrtc manifest was not found: $pluginManifest"
}
$manifest = Get-Content -LiteralPath $pluginManifest -Raw
if ($manifest -notmatch '(?m)^      windows:\r?\n        pluginClass: FlutterWebRTCPlugin\r?$') {
  $replacement = '$1' + "      windows:`r`n        pluginClass: FlutterWebRTCPlugin`r`n"
  $updatedManifest = $manifest -replace '(?m)^(      macos:\r?\n        pluginClass: FlutterWebRTCPlugin\r?\n)', $replacement
  if ($updatedManifest -eq $manifest) {
    throw "Could not restore the flutter_webrtc Windows plugin declaration."
  }
  [System.IO.File]::WriteAllText(
    $pluginManifest,
    $updatedManifest,
    [System.Text.UTF8Encoding]::new($false)
  )
}

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$generatedDir = Join-Path $PSScriptRoot "windows\flutter"
$generatedFiles = @(
  (Join-Path $generatedDir "generated_plugins.cmake"),
  (Join-Path $generatedDir "generated_plugin_registrant.cc")
)
if (-not (Select-String -Path $generatedFiles -Pattern 'flutter_webrtc|FlutterWebRTCPlugin' -Quiet)) {
  throw "flutter_webrtc was not registered as a Windows plugin."
}

Write-Host "Verified flutter_webrtc native plugin registration." -ForegroundColor Green
