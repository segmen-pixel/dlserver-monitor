# dlserver-monitor

Cross-platform live monitor for a remote NVIDIA Linux ML server.

One Bash helper on the server emits a CSV line of GPU/CPU stats; the Windows (Rainmeter) and Mac (Übersicht) clients fetch it over SSH every 3 seconds and render bar + sparkline panels on the desktop.

```
┌──────────────────────────┐
│  DL-SERVER2              │
│                          │
│  GPU 0  RTX 3080 Ti      │
│  Temp  ▰▱▱▱  ─/\─/\─   41 °C │
│  Fan   ▰▰▰▱  ▔▔▔▁▁▁    76%   │
│  Util  ▰▰▰▰  ▁▁▁▔▔▔   100%   │
│  ...                     │
│  GPU 1  ...              │
│  CPU  i9-7900X  PA120    │
│  Pkg   ▰▰▱▱▱  ──‾‾──   68 °C │
│  Fan   ▰▰▰▱▱  ──‾‾──  900 RPM│
└──────────────────────────┘
```

## Architecture

```
┌─ Linux trainer ────────────────────┐      ┌─ Windows ─────┐
│  /usr/local/bin/trainer-stats      │      │  fetch-stats  │
│  ↓                                 │  SSH │  .ps1 (3s loop)│
│  CSV: g0t,g0f,g0u,g0m,g0p,g1...,c1 │ ───→ │  ↓             │
│  (nvidia-smi + lm-sensors)         │      │  %TEMP%\stats  │
│                                    │      │  ↓             │
│  systemd: gpu-fan-control.service  │      │  Rainmeter     │
│  (NVML fan curve, X-server-free)   │      │  WebParser     │
└────────────────────────────────────┘      └────────────────┘
                                            ┌─ Mac ─────────┐
                                       SSH  │  Übersicht    │
                                      ───→  │  index.coffee │
                                            │  (3s polling) │
                                            └────────────────┘
```

## Layout

| dir | platform | content |
|---|---|---|
| [`trainer/`](trainer/) | Linux server | Bash helpers, NVML fan-control daemon, systemd unit, Conky overlay |
| [`windows/`](windows/) | Windows desktop | Rainmeter skin (`.ini`), background SSH loop (`.ps1` + `.vbs`) |
| [`mac/DLServer2.widget/`](mac/DLServer2.widget/) | macOS | Übersicht widget (CoffeeScript + Stylus) |

## Install — trainer side (do first)

Trainer needs `nvidia-smi`, `lm-sensors`, and the `nvidia-ml-py` Python package somewhere. Then:

```bash
# stat helpers
sudo install -m 0755 trainer/trainer-stats.sh /usr/local/bin/trainer-stats
sudo install -m 0755 trainer/cpu-stat.sh      /usr/local/bin/cpu-stat
sudo install -m 0755 trainer/gpu-stat-norm.sh /usr/local/bin/gpu-stat-norm

# (optional) GPU fan curve daemon  — needs nvidia-ml-py importable as root
sudo install -m 0755 trainer/gpu-fan-control.py    /usr/local/bin/gpu-fan-control.py
sudo install -m 0644 trainer/gpu-fan-control.conf  /etc/gpu-fan-control.conf
sudo install -m 0644 trainer/gpu-fan-control.service /etc/systemd/system/gpu-fan-control.service
# edit ExecStart in the .service to point at the python you want to use
sudo systemctl daemon-reload
sudo systemctl enable --now gpu-fan-control

# (optional) CPU fan curve for NCT6795D super-IO (MSI X299, etc.)
# Aggressive curve: 30C/29% → 50C/60% → 65C/90% → 75C/100%
# Edit thresholds in cpu-fan-curve.sh if your cooler is different.
sudo install -m 0755 trainer/cpu-fan-curve.sh         /usr/local/sbin/cpu-fan-curve.sh
sudo install -m 0644 trainer/cpu-fan-curve.service    /etc/systemd/system/cpu-fan-curve.service
sudo install -m 0644 trainer/nct6775-modules-load.conf /etc/modules-load.d/nct6775.conf
sudo systemctl daemon-reload
sudo systemctl enable --now cpu-fan-curve

# (optional) Conky desktop overlay for trainer's own GUI session
sudo apt install conky-all
mkdir -p ~/.config/conky
cp trainer/conky-dual-gpu.conf ~/.config/conky/dual-gpu.conf

# verify
/usr/local/bin/trainer-stats
# → e.g. 38,67,0,6080,99.84,41,78,0,11328,106.84,75,76,900
```

The CSV is 13 fields, in this order:

| # | field | unit |
|---|---|---|
| 1 | `gpu0_temp` | °C |
| 2 | `gpu0_fan` | % |
| 3 | `gpu0_util` | % |
| 4 | `gpu0_mem` | MiB |
| 5 | `gpu0_power` | W |
| 6 | `gpu1_temp` | °C |
| 7 | `gpu1_fan` | % |
| 8 | `gpu1_util` | % |
| 9 | `gpu1_mem` | MiB |
| 10 | `gpu1_power` | W |
| 11 | `cpu_pkg` | °C (CPU package) |
| 12 | `cpu_max` | °C (hottest core) |
| 13 | `cpu_fan_rpm` | RPM (NCT6795D `fan2_input`, 0 if not present) |

> **VRAM cap is hardcoded to 12288 MiB** in the clients (3080 Ti). Change in the skin/widget if your card is different.

## Install — Windows (Rainmeter)

```powershell
winget install Rainmeter.Rainmeter
```

Place the skin:

```powershell
$dst = "$env:USERPROFILE\Documents\Rainmeter\Skins\DLServer2"
mkdir $dst -Force
copy windows\* $dst\
```

Configure SSH client + key auth so `ssh trainer ...` works without prompting (host alias in `~/.ssh/config` pointing to your server, key in `~/.ssh/id_ed25519`).

Start the fetch loop and add it to startup:

```powershell
$wsh = New-Object -ComObject WScript.Shell
$lnk = "$([Environment]::GetFolderPath('Startup'))\trainer-stats-fetch.lnk"
$s = $wsh.CreateShortcut($lnk)
$s.TargetPath = "wscript.exe"
$s.Arguments  = """$dst\start-fetch.vbs"""
$s.WindowStyle = 7
$s.Save()
Start-Process wscript.exe -ArgumentList """$dst\start-fetch.vbs""" -WindowStyle Hidden
```

Activate the skin: Rainmeter tray icon → Manage → DLServer2 → DLServer2.ini → Load.

The PS loop writes `%TEMP%\trainer-stats.txt` every 3 s; the Rainmeter skin reads that file via `WebParser` and parses the 13 capture groups.

## Install — Mac (Übersicht)

See [`mac/DLServer2.widget/README.md`](mac/DLServer2.widget/README.md) for the full guide. TL;DR:

```bash
brew install --cask ubersicht
ssh-copy-id -i ~/.ssh/id_ed25519.pub adstec@<trainer-ip>
echo -e "\nHost trainer\n  HostName <trainer-ip>\n  User adstec\n  IdentityFile ~/.ssh/id_ed25519" >> ~/.ssh/config
cp -r mac/DLServer2.widget "$HOME/Library/Application Support/Übersicht/widgets/"
osascript -e 'tell application "Übersicht" to refresh'
```

The widget runs `ssh trainer /usr/local/bin/trainer-stats` directly every 3 s — no intermediate file needed (Mac's Übersicht handles process spawning better than Rainmeter does on Windows).

## Why the Windows side uses a file but Mac doesn't

Rainmeter's `RunCommand` plugin couldn't reliably launch `ssh.exe` with our setup (silent failure, no output captured). The workaround: a hidden PowerShell loop writes to a temp file, Rainmeter polls the file. Übersicht has no such issue — its `command:` field spawns a real shell and captures stdout natively.

## License

Apache-2.0.
