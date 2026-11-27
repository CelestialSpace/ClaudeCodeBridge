[CmdletBinding()]
param(
    [string]$ProxyServer = '10.40.111.234:8633',
    [string]$ProxyOverride = '127.0.0.1;localhost;<local>;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*',
    [switch]$Restore
)
$ErrorActionPreference = 'Stop'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$policyKey = 'HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings'
$backupFile = Join-Path $env:USERPROFILE '.claudecodebridge-proxy-backup.json'

function Test-WinInetLocked {
    try {
        $val = Get-ItemPropertyValue -Path $policyKey -Name 'ProxySettingsPerUser' -ErrorAction Stop
        if ($val -eq 0) { return '机器级代理策略已锁定，用户级设置可能不生效' }
    } catch {}
    try {
        $val = Get-ItemPropertyValue -Path $policyKey -Name 'ProxyEnable' -ErrorAction Stop
        if ($val -ne $null) { return '组策略锁定了 ProxyEnable' }
    } catch {}
    return $null
}

$locked = Test-WinInetLocked
if ($locked) { Write-Warning $locked }

if ($Restore) {
    if (-not (Test-Path $backupFile)) { throw "Backup file not found: $backupFile" }
    $b = Get-Content $backupFile -Raw | ConvertFrom-Json
    if ($b.ProxyEnable) { Set-ItemProperty -Path $key -Name ProxyEnable -Value $b.ProxyEnable } else { Remove-ItemProperty -Path $key -Name ProxyEnable -ErrorAction SilentlyContinue }
    if ($null -ne $b.ProxyServer) { Set-ItemProperty -Path $key -Name ProxyServer -Value $b.ProxyServer } else { Remove-ItemProperty -Path $key -Name ProxyServer -ErrorAction SilentlyContinue }
    if ($null -ne $b.ProxyOverride) { Set-ItemProperty -Path $key -Name ProxyOverride -Value $b.ProxyOverride } else { Remove-ItemProperty -Path $key -Name ProxyOverride -ErrorAction SilentlyContinue }
    Remove-Item $backupFile -Force
    Write-Host 'WinINET proxy restored.'
} else {
    $current = @{
        ProxyEnable = if (Test-PathProperty $key 'ProxyEnable') { Get-ItemPropertyValue -Path $key -Name 'ProxyEnable' } else { $null }
        ProxyServer = if (Test-PathProperty $key 'ProxyServer') { Get-ItemPropertyValue -Path $key -Name 'ProxyServer' } else { $null }
        ProxyOverride = if (Test-PathProperty $key 'ProxyOverride') { Get-ItemPropertyValue -Path $key -Name 'ProxyOverride' } else { $null }
    }
    $current | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupFile -Encoding utf8

    Set-ItemProperty -Path $key -Name ProxyEnable -Value 1
    Set-ItemProperty -Path $key -Name ProxyServer -Value $ProxyServer
    Set-ItemProperty -Path $key -Name ProxyOverride -Value $ProxyOverride

    # Notify WinINET that proxy settings changed
    try {
        $sig = '[DllImport("wininet.dll", SetLastError=true, CharSet=CharSet.Auto)] public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);'
        $type = Add-Type -MemberDefinition $sig -Name WinInet -Namespace Native -PassThru -ErrorAction Stop
        $type::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) # INTERNET_OPTION_SETTINGS_CHANGED
        $type::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) # INTERNET_OPTION_REFRESH
    } catch {
        Write-Warning 'WinINET refresh API failed; you may need to restart Cursor for proxy to take effect.'
    }
    Write-Host "WinINET proxy set to $ProxyServer (override: $ProxyOverride)"
    Write-Host "Backup saved to $backupFile. Run with -Restore to undo."
}

function Test-PathProperty($path, $name) {
    try { Get-ItemPropertyValue -Path $path -Name $name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}
