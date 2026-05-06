$ErrorActionPreference = 'SilentlyContinue'
$out = "$env:TEMP\trainer-stats.txt"
$tmp = "$env:TEMP\trainer-stats.tmp"
$err = "$env:TEMP\trainer-stats.err"
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'

while ($true) {
    $proc = Start-Process -FilePath $ssh `
        -ArgumentList @(
            '-o', 'ConnectTimeout=5',
            '-o', 'ServerAliveInterval=3',
            '-o', 'ServerAliveCountMax=2',
            '-o', 'BatchMode=yes',
            'trainer', '/usr/local/bin/trainer-stats'
        ) `
        -RedirectStandardOutput $tmp `
        -RedirectStandardError $err `
        -WindowStyle Hidden `
        -PassThru

    if (-not $proc.WaitForExit(12000)) {
        try { $proc.Kill() } catch {}
        try { $proc.WaitForExit(2000) | Out-Null } catch {}
    } else {
        $content = Get-Content -Path $tmp -Raw -ErrorAction SilentlyContinue
        if ($content -and $content.Trim()) {
            Set-Content -Path $out -Value $content.TrimEnd("`r", "`n") -Encoding ASCII -NoNewline
        }
    }
    Start-Sleep -Seconds 3
}
