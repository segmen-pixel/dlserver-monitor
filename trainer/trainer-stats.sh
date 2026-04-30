#!/bin/bash
# Output all monitoring stats as CSV (one line):
# gpu0_temp,gpu0_fan,gpu0_util,gpu0_mem,gpu0_power,gpu1_temp,gpu1_fan,gpu1_util,gpu1_mem,gpu1_power,cpu_pkg,cpu_max
g=$(nvidia-smi --query-gpu=temperature.gpu,fan.speed,utilization.gpu,memory.used,power.draw --format=csv,noheader,nounits 2>/dev/null | tr -d ' %W' | tr '\n' ',' | sed 's/,$//')
cpu_pkg=$(/usr/local/bin/cpu-stat pkg)
cpu_max=$(/usr/local/bin/cpu-stat max)
echo "$g,$cpu_pkg,$cpu_max"
