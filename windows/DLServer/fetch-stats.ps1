$ErrorActionPreference = 'SilentlyContinue'
$out = "$env:TEMP\dlserver-stats.txt"
$script = "$env:USERPROFILE\bin\trainer-stats.ps1"
while ($true) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script 2>$null | Set-Content -Path $out -Encoding ASCII -NoNewline
    Start-Sleep -Seconds 3
}
