' Hidden launcher for rainmeter-refresh-loop.ps1
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""C:\Users\ADSTEC\bin\rainmeter-refresh-loop.ps1""", 0, False
