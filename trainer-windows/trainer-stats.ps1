$ErrorActionPreference = 'SilentlyContinue'
$g = (& nvidia-smi --query-gpu=temperature.gpu,fan.speed,utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits)
$g = $g -replace '[ %W]', ''
$gpu_csv = ($g -join ',')
$tz = Get-CimInstance -Namespace root/WMI -ClassName MSAcpi_ThermalZoneTemperature
$temps = @()
foreach ($z in $tz) {
  $c = [math]::Round(($z.CurrentTemperature / 10) - 273.15)
  if ($c -gt 0 -and $c -lt 150) { $temps += $c }
}
if ($temps.Count -eq 0) { $temps = @(0) }
$cpu_pkg = ($temps | Measure-Object -Average).Average
$cpu_max = ($temps | Measure-Object -Maximum).Maximum
"$gpu_csv,$([int]$cpu_pkg),$([int]$cpu_max)"
