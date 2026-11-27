@echo off
rem Cursor client launcher with HTTP CONNECT proxy for official-site traffic.
rem Use this ONLY if WinINET proxy is locked by group policy (HKCU setting ignored).
rem This sets the proxy for Cursor process only; your browser login pop-up still
rem needs its own proxy setting (Edge/Chrome --proxy-server or system proxy).

@echo off
setlocal
set "CURSOR=%LOCALAPPDATA%\Programs\Cursor\Cursor.exe"
if not exist "%CURSOR%" (
    echo Cursor not found at %CURSOR%
    pause
    exit /b 1
)

echo Stopping existing Cursor...
taskkill /IM Cursor.exe /T /F >nul 2>&1
timeout /t 2 >nul

echo Starting Cursor with proxy http://10.40.111.234:8633 ...
start "" "%CURSOR%" --proxy-server=http://10.40.111.234:8633
