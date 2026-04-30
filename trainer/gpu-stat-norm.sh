#!/bin/bash
# Usage: gpu-stat-norm <nvidia-smi-metric> <gpu_id> [scale]
# scale = max-value to normalize to 0-100. Default = 100 (raw passthrough).
metric=$1
gpu_id=$2
scale=${3:-100}
val=$(nvidia-smi --query-gpu="$metric" --format=csv,noheader,nounits -i "$gpu_id" 2>/dev/null | tr -d ' %W' | head -1)
[ -z "$val" ] && val=0
awk -v v="$val" -v s="$scale" 'BEGIN{ if (s==100) printf "%d", v; else printf "%d", v*100/s }'
