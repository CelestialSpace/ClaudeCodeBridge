@echo off
setlocal
title VIBE Local Unified Proxy 0.0.0.0:8633 (HTTP CONNECT + SOCKS5)
cd /d "%~dp0"

rem 1) portable node.exe next to this script
if exist "%~dp0node.exe" (
    "%~dp0node.exe" "%~dp0proxy.js"
    goto :done
)

rem 2) node on PATH
where node >nul 2>nul
if %errorlevel%==0 (
    node "%~dp0proxy.js"
    goto :done
)

rem 3) Vibe api-worker bundled node (this machine)
if exist "%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd" (
    "%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd" "%~dp0proxy.js"
    goto :done
)

echo [ERROR] Node.js not found.
echo Install Node.js, or put node.exe in this folder next to proxy.js.
pause

:done
echo.
echo Proxy exited with code %ERRORLEVEL%. Press any key to close.
pause >nul
