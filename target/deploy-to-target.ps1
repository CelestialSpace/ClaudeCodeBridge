[CmdletBinding()]
param(
    [string]$CursorInstallPath = (Join-Path $env:LOCALAPPDATA 'Programs\Cursor'),
    [switch]$SkipVersionCheck
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$activation = Join-Path $root 'activation'
$patchRoot = Join-Path $root 'patches'

$augproFile = Join-Path $activation 'augpro.json'
$authFile = Join-Path $activation 'api-worker\.auth'
$settingsFile = Join-Path $activation 'cursor-settings.json'
foreach ($f in @($augproFile,$authFile,$settingsFile)) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { throw "Required package file missing: $f. Run update-from-local.ps1 on the source machine first." }
}

$resourceRoot = Join-Path $CursorInstallPath 'resources\app'
if (-not (Test-Path -LiteralPath (Join-Path $resourceRoot 'package.json'))) { throw "Cursor app not found at '$resourceRoot'. Specify -CursorInstallPath." }
$version = (Get-Content -LiteralPath (Join-Path $resourceRoot 'package.json') -Raw | ConvertFrom-Json).version
$packageVersionPath = Join-Path $root 'cursor-version.txt'
$packageVersion = if (Test-Path $packageVersionPath) { (Get-Content $packageVersionPath -Raw).Trim() } else { '' }
if ($packageVersion -and $version -ne $packageVersion) {
    Write-Warning "TARGET Cursor version is $version; package was captured from $packageVersion. Patch compatibility is not guaranteed."
    if (-not $SkipVersionCheck) { $answer = Read-Host 'Continue anyway? (y/N)'; if ($answer -notmatch '^(y|yes)$') { throw 'Deployment cancelled due to Cursor version mismatch.' } }
}

# Confirm endpoint values before writing the target user's obfuscated activation file.
$plain = Get-Content -LiteralPath $augproFile -Raw | ConvertFrom-Json
if ($plain.API_WORKER_URL -ne 'http://10.40.111.234:8634') { throw 'augpro.json API_WORKER_URL is not the expected bridge URL; update the package first.' }

# Back up the TARGET's existing destination files before replacing them.
$backupRoot = Join-Path $resourceRoot '.claudecodebridge-backup'
$files = Get-ChildItem -LiteralPath $patchRoot -File -Recurse
foreach ($file in $files) {
    $relative = $file.FullName.Substring($patchRoot.Length).TrimStart('\','/')
    $destination = Join-Path $resourceRoot $relative
    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Patch destination missing in this Cursor version: $relative" }
}
New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
foreach ($file in $files) {
    $relative = $file.FullName.Substring($patchRoot.Length).TrimStart('\','/')
    $destination = Join-Path $resourceRoot $relative
    $backup = Join-Path $backupRoot $relative
    if (-not (Test-Path -LiteralPath $backup)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $backup -Parent) | Out-Null
        Copy-Item -LiteralPath $destination -Destination $backup
    }
}

# Apply the captured, Vibe助手-patched Cursor JS files (includes matching .bak files).
foreach ($file in $files) {
    $relative = $file.FullName.Substring($patchRoot.Length).TrimStart('\','/')
    $destination = Join-Path $resourceRoot $relative
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

# Install per-user activation material. The API worker remains on the source PC.
$userHome = $env:USERPROFILE
$obfuscated = [System.Text.Encoding]::UTF8.GetBytes(($plain | ConvertTo-Json -Compress -Depth 10))
for ($i=0; $i -lt $obfuscated.Length; $i++) { $obfuscated[$i] = $obfuscated[$i] -bxor 37 }
[System.IO.File]::WriteAllBytes((Join-Path $userHome '.augpro.json'), $obfuscated)
$authDir = Join-Path $userHome 'api-worker'
New-Item -ItemType Directory -Force -Path $authDir | Out-Null
Copy-Item -LiteralPath $authFile -Destination (Join-Path $authDir '.auth') -Force

# Merge only the network compatibility settings; preserve the TARGET user's other settings.
$settingsPath = Join-Path $env:APPDATA 'Cursor\User\settings.json'
New-Item -ItemType Directory -Force -Path (Split-Path $settingsPath -Parent) | Out-Null
$current = if (Test-Path $settingsPath) { Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
$sourceSettings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable
foreach ($key in @('cursor.general.disableHttp2','cursor.general.disableHttp1SSE')) { if ($sourceSettings.ContainsKey($key)) { $current[$key] = $sourceSettings[$key] } }
$current | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding utf8

Write-Host "Deployed Vibe助手 activation files to $userHome"
Write-Host "Cursor version: $version; API bridge: $($plain.API_WORKER_URL)"
Write-Host 'Restart Cursor. Ensure the source PC forwarder is listening on port 8634.'
