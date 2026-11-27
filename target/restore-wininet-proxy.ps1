[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$backupFile = Join-Path $env:USERPROFILE '.claudecodebridge-proxy-backup.json'
if (-not (Test-Path $backupFile)) { throw "Backup file not found: $backupFile. Run set-wininet-proxy.ps1 first." }
& (Join-Path $PSScriptRoot 'set-wininet-proxy.ps1') -Restore
