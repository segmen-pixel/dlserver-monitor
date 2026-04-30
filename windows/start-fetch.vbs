' Hidden launcher for fetch-stats.ps1
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & WScript.ScriptFullName & "\..\fetch-stats.ps1""", 0, False
