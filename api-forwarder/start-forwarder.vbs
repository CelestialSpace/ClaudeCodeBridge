' VIBE API Forwarder 0.0.0.0:8634 -> 127.0.0.1:9182, hidden background window
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
    nodeExe = "node"
End If

sh.Run """" & nodeExe & """ """ & base & "\forwarder.js""", 0, False
