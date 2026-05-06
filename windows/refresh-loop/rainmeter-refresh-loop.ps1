# Rainmeter periodic refresh loop.
# Sends !RefreshApp every 30 minutes so widgets don't get stuck after long uptimes.
# Skips silently if Rainmeter isn't running (so killing Rainmeter intentionally
# doesn't restart it).
$ErrorActionPreference = 'SilentlyContinue'
$exe = 'C:\Program Files\Rainmeter\Rainmeter.exe'
$intervalSec = 1800  # 30 min

while ($true) {
    if (Get-Process -Name Rainmeter -ErrorAction SilentlyContinue) {
        & $exe !RefreshApp 2>$null | Out-Null
    }
    Start-Sleep -Seconds $intervalSec
}
