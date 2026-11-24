param(
    [string]$Version = "2.1.328",
    [ValidateSet("x64", "arm64")][string]$Arch = "x64"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$platform = if ($Arch -eq "arm64") { "win32-arm64" } else { "win32-x64" }
$base = "https://downloads.claude.ai/claude-code-releases/$Version"
$url = "$base/$platform/claude.exe"
$dir = Join-Path $env:USERPROFILE ".claude\downloads"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$out = Join-Path $dir "claude-$Version-$platform.exe"

Write-Host "Manifest: $base/manifest.json"
$manifest = Invoke-RestMethod -Uri "$base/manifest.json" -TimeoutSec 60
$expectSize = [long]$manifest.platforms.$platform.size
$expectHash = $manifest.platforms.$platform.checksum.ToLower()
Write-Host "URL: $url"
Write-Host "Expected size: $expectSize bytes"

Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromMinutes(30)

$maxAttempts = 1000
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    $have = if (Test-Path $out) { (Get-Item $out).Length } else { 0 }
    if ($have -ge $expectSize) { break }
    Write-Host ("[{0}] attempt {1}: have {2}/{3}" -f (Get-Date -Format 'HH:mm:ss'), $attempt, $have, $expectSize)
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get), $url
        $req.Headers.UserAgent.ParseAdd("Mozilla/5.0")
        if ($have -gt 0) {
            $req.Headers.Range = New-Object System.Net.Http.Headers.RangeHeaderValue $have, $null
        }
        $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if ($resp.StatusCode -ne [System.Net.HttpStatusCode]::OK -and $resp.StatusCode -ne [System.Net.HttpStatusCode]::PartialContent) {
            throw "HTTP $([int]$resp.StatusCode) $($resp.StatusCode)"
        }
        if ($resp.StatusCode -eq [System.Net.HttpStatusCode]::OK -and $have -gt 0) {
            Write-Host "Server ignored Range; restarting from 0"
            Remove-Item -Force $out -ErrorAction SilentlyContinue
        }
        $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $fs = [System.IO.File]::Open($out, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write)
        try { $stream.CopyTo($fs, 81920) } finally { $fs.Dispose(); $stream.Dispose(); $resp.Dispose() }
    }
    catch {
        Write-Host ("[{0}] attempt {1} failed: {2}" -f (Get-Date -Format 'HH:mm:ss'), $attempt, $_.Exception.Message)
        Start-Sleep -Seconds 3
    }
}

$have = (Get-Item $out).Length
if ($have -ne $expectSize) { throw "Download incomplete: $have / $expectSize" }
Write-Host "Verifying SHA256..."
$actual = (Get-FileHash -Path $out -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expectHash) { throw "Checksum mismatch! actual=$actual expected=$expectHash" }
Write-Host "Checksum OK. Running installer (claude.exe install)..."
& $out install
$code = $LASTEXITCODE
if ($code -ne 0) { throw "installer exited with $code" }
Write-Host "Done. Open a NEW terminal and run: claude --version"
