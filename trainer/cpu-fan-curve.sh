#!/bin/bash
# Apply aggressive CPU fan curve to NCT6795D pwm2 (CPU_FAN header).
# Find nct6795 hwmon path (varies across boots) and write the curve.
# Curve: 30C/29% → 50C/60% → 65C/90% → 75C/100% → 85C/100%
# Suited for Thermalright PA120 (Peerless Assassin 120) on i9-7900X under
# heavy ML workloads (open-frame chassis, GPU exhaust nearby).
for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat $h/name 2>/dev/null)" = "nct6795" ]; then
        echo 30000 > $h/pwm2_auto_point1_temp; echo  76 > $h/pwm2_auto_point1_pwm
        echo 50000 > $h/pwm2_auto_point2_temp; echo 153 > $h/pwm2_auto_point2_pwm
        echo 65000 > $h/pwm2_auto_point3_temp; echo 230 > $h/pwm2_auto_point3_pwm
        echo 75000 > $h/pwm2_auto_point4_temp; echo 255 > $h/pwm2_auto_point4_pwm
        echo 85000 > $h/pwm2_auto_point5_temp; echo 255 > $h/pwm2_auto_point5_pwm
        echo "applied: 30C/29% 50C/60% 65C/90% 75C/100%"
        exit 0
    fi
done
echo "nct6795 hwmon not found"
exit 1
