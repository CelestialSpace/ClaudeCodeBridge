' VIBE Local Unified Proxy 0.0.0.0:8633 (HTTP CONNECT + SOCKS5), hidden background window
' Double-click to run hidden; copy a shortcut into shell:startup for boot auto-launch.
Dim fso, base, sh, env, nodeExe
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
base = fso.GetParentFolderName(WScript.ScriptFullName)
Set env = sh.Environment("PROCESS")

If fso.FileExists(base & "\node.exe") Then
    nodeExe = base & "\node.exe"
ElseIf fso.FileExists(sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd")) Then
    nodeExe = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\api-worker-electron\resources\bin\node.cmd")
Else
    nodeExe = "node"   ' rely on PATH
End If

sh.Run """" & nodeExe & """ """ & base & "\proxy.js""", 0, False
