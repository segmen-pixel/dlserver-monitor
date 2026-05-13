$ErrorActionPreference = 'SilentlyContinue'

# GPU stats (nvidia-smi)
$g = (& nvidia-smi --query-gpu=temperature.gpu,fan.speed,utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits)
$g = $g -replace '[ %W]', ''
$gpu_csv = ($g -join ',')

# CPU temps via WMI/CIM. MSAcpi_ThermalZoneTemperature occasionally hangs the
# CIM session indefinitely; isolate the call in a child Job so we can enforce a
# hard timeout and not pile up dead powershell.exe processes.
$temps = @()
$job = Start-Job -ScriptBlock {
  $tz = Get-CimInstance -Namespace root/WMI -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
  $out = @()
  foreach ($z in $tz) {
    $c = [math]::Round(($z.CurrentTemperature / 10) - 273.15)
    if ($c -gt 0 -and $c -lt 150) { $out += $c }
  }
  ,$out
}
if (Wait-Job -Job $job -Timeout 3) {
  $temps = Receive-Job -Job $job
} else {
  Stop-Job -Job $job -ErrorAction SilentlyContinue
}
Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

if ($temps.Count -eq 0) { $temps = @(0) }
$cpu_pkg = ($temps | Measure-Object -Average).Average
$cpu_max = ($temps | Measure-Object -Maximum).Maximum
"$gpu_csv,$([int]$cpu_pkg),$([int]$cpu_max)"
