' api-forwarder 后台启动器（隐藏窗口）
' 双击运行；可复制到 Startup 目录实现开机自启
Dim fso, base, sh
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
Set sh = CreateObject("WScript.Shell")
sh.Run """C:\Users\zhut\AppData\Local\Programs\api-worker-electron\resources\bin\node.cmd""" & " """ & base & "\forwarder.js""", 0, False
