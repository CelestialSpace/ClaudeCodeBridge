@echo off
setlocal
title VIBE API Forwarder 0.0.0.0:8634 to 127.0.0.1:9182
cd /d "%~dp0"
set LISTEN_PORT=8634

rem 1) portable node.exe next to this script
if exist "%~dp0node.exe" (
    "%~dp0node.exe" "%~dp0forwarder.js"
    goto :done
)

rem 2) node on PATH
where node >nul 2>nul
if %errorlevel%==0 (
    node "%~dp0forwarder.js"
    goto :done
)

rem 3) Vibe api-worker bundled node (this machine)
if exist "%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd" (
    "%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd" "%~dp0forwarder.js"
    goto :done
)

echo [ERROR] Node.js not found.
echo Install Node.js, or put node.exe in this folder next to forwarder.js.
pause

:done
echo.
echo Forwarder exited with code %ERRORLEVEL%. Press any key to close.
pause >nul
