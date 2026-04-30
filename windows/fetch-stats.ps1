$ErrorActionPreference = 'SilentlyContinue'
$out = "$env:TEMP\trainer-stats.txt"
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
while ($true) {
    & $ssh -o ConnectTimeout=5 trainer "/usr/local/bin/trainer-stats" 2>$null | Set-Content -Path $out -Encoding ASCII -NoNewline
    Start-Sleep -Seconds 3
}
