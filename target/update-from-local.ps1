[CmdletBinding()]
param(
    [string]$CursorInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\Cursor'),
    [string]$WorkerPort = '9182',
    [string]$BridgeUrl = 'http://10.40.111.234:8634'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$resourceRoot = Join-Path $CursorInstallPath 'resources\app'
$userHome = $env:USERPROFILE
$augproPath = Join-Path $userHome '.augpro.json'
$authPath = Join-Path $userHome 'api-worker\.auth'
$settingsPath = Join-Path $env:APPDATA 'Cursor\User\settings.json'

if (-not (Test-Path $augproPath -PathType Leaf)) { throw "Missing local activation file: $augproPath. Activate Cursor with Vibe助手 first." }
if (-not (Test-Path $authPath -PathType Leaf)) { throw "Missing worker auth file: $authPath" }
if (-not (Test-Path (Join-Path $resourceRoot 'package.json') -PathType Leaf)) { throw "Cursor app not found: $resourceRoot" }

$bytes = [System.IO.File]::ReadAllBytes($augproPath)
for ($i=0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor 37 }
$plain = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
$plain.API_WORKER_URL = $BridgeUrl.TrimEnd('/')
$plain.API_WORKER_HOST = ([uri]$BridgeUrl).Authority
$plain.LS_URL = $BridgeUrl.TrimEnd('/')
$plain | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $root 'activation\augpro.json') -Encoding utf8
Copy-Item $authPath (Join-Path $root 'activation\api-worker\.auth') -Force
if (Test-Path $settingsPath) { Copy-Item $settingsPath (Join-Path $root 'activation\cursor-settings.json') -Force }

$version = (Get-Content (Join-Path $resourceRoot 'package.json') -Raw | ConvertFrom-Json).version
Set-Content -LiteralPath (Join-Path $root 'cursor-version.txt') -Value $version -NoNewline -Encoding ascii

$relativeFiles = @(
    'out\vs\workbench\workbench.desktop.main.js',
    'out\vs\workbench\workbench.desktop.main.js.bak',
    'out\vs\workbench\workbench.glass.main.js',
    'out\vs\workbench\workbench.glass.main.js.bak',
    'out\vs\workbench\api\node\extensionHostProcess.js',
    'out\vs\workbench\api\node\extensionHostProcess.js.bak',
    'extensions\cursor-always-local\dist\main.js',
    'extensions\cursor-always-local\dist\main.js.bak',
    'extensions\cursor-agent-host\dist\main.js',
    'extensions\cursor-agent-host\dist\main.js.bak'
)
$missing = @()
foreach ($relative in $relativeFiles) {
    $source = Join-Path $resourceRoot $relative
    if (-not (Test-Path $source -PathType Leaf)) { $missing += $relative }
}
if ($missing.Count) { throw "Cursor $version is missing expected activation patch files:`n$($missing -join "`n")" }
foreach ($relative in $relativeFiles) {
    $source = Join-Path $resourceRoot $relative
    $destination = Join-Path (Join-Path $root 'patches') $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $destination -Parent) | Out-Null
    Copy-Item $source $destination -Force
}

Write-Host "Updated TARGET deployment package from local Vibe助手-activated Cursor $version"
Write-Host "Captured files under: $root"
Write-Host "Bridge URL embedded in plaintext package: $BridgeUrl"
Write-Host 'Review changes, then commit/push only the documented package. Keep activation/ and patches/ ignored; transfer those files offline to TARGET.'
