#!/bin/bash
# Output all monitoring stats as CSV (one line, 13 fields):
# gpu0_temp,gpu0_fan,gpu0_util,gpu0_mem,gpu0_power,
# gpu1_temp,gpu1_fan,gpu1_util,gpu1_mem,gpu1_power,
# cpu_pkg,cpu_max,cpu_fan_rpm
g=$(nvidia-smi --query-gpu=temperature.gpu,fan.speed,utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' %W' | tr '\n' ',' | sed 's/,$//')
cpu_pkg=$(/usr/local/bin/cpu-stat pkg)
cpu_max=$(/usr/local/bin/cpu-stat max)
# CPU fan: read fan2_input from nct6795 hwmon (path varies across boots)
cpu_fan=0
for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat $h/name 2>/dev/null)" = "nct6795" ]; then
        cpu_fan=$(cat $h/fan2_input 2>/dev/null || echo 0)
        break
    fi
done
echo "$g,$cpu_pkg,$cpu_max,$cpu_fan"
