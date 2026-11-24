@echo off
title API Forwarder 0.0.0.0:8634 to 127.0.0.1:9182
cd /d "%~dp0"
set LISTEN_PORT=8634
"C:\Users\zhut\AppData\Local\Programs\api-worker-electron\resources\bin\node.cmd" "%~dp0forwarder.js"
echo.
echo Forwarder exited with code %ERRORLEVEL%. Press any key to close.
pause >nul
