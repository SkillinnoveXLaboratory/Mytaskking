$ErrorActionPreference = "Stop"

# flutter_webrtc is needed by shared mobile call code, but its current Windows
# native plugin crashes during registration before the desktop UI can start.
# Flutter regenerates its plugin files during build, so remove only the Windows
# platform entry from the temporary Pub cache copy before regenerating them.
$dependenciesFile = Join-Path $PSScriptRoot ".flutter-plugins-dependencies"
if (-not (Test-Path -LiteralPath $dependenciesFile)) {
  throw "Flutter plugin metadata was not found: $dependenciesFile. Run flutter pub get first."
}

$metadata = Get-Content -LiteralPath $dependenciesFile -Raw | ConvertFrom-Json
$plugin = @($metadata.plugins.windows) | Where-Object { $_.name -eq "flutter_webrtc" } | Select-Object -First 1
if ($plugin) {
  $pluginManifest = Join-Path $plugin.path "pubspec.yaml"
  if (-not (Test-Path -LiteralPath $pluginManifest)) {
    throw "flutter_webrtc manifest was not found: $pluginManifest"
  }
  $manifest = Get-Content -LiteralPath $pluginManifest -Raw
  $updatedManifest = [regex]::Replace(
    $manifest,
    '(?m)^      windows:\r?\n        pluginClass: FlutterWebRTCPlugin\r?\n',
    ''
  )
  if ($updatedManifest -ne $manifest) {
    [System.IO.File]::WriteAllText(
      $pluginManifest,
      $updatedManifest,
      [System.Text.UTF8Encoding]::new($false)
    )
  }
}

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$generatedDir = Join-Path $PSScriptRoot "windows\flutter"
$generatedFiles = @(
  (Join-Path $generatedDir "generated_plugins.cmake"),
  (Join-Path $generatedDir "generated_plugin_registrant.cc")
)
if (Select-String -Path $generatedFiles -Pattern 'flutter_webrtc|FlutterWebRTCPlugin' -Quiet) {
  throw "flutter_webrtc is still registered as a Windows plugin."
}

Write-Host "Excluded flutter_webrtc native plugin from the Windows build." -ForegroundColor Yellow
