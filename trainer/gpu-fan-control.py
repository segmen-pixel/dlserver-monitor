#!/usr/bin/env python3
"""GPU fan curve daemon for headless NVIDIA boxes.

Reads /etc/gpu-fan-control.conf (temp_c, fan_pct), polls all GPUs, sets
each fan to the linearly-interpolated target. On exit (or `reset`
argument), restores the driver's default auto curve.
"""
from __future__ import annotations
import os
import sys
import time
import signal
import logging
from pathlib import Path

import pynvml

DEFAULT_CONF = Path("/etc/gpu-fan-control.conf")
POLL_INTERVAL = 2.0  # seconds
HYSTERESIS = 2  # only update fan if target differs by >= this %

logging.basicConfig(
    format="%(asctime)s [fanctl] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    level=logging.INFO,
)
log = logging.getLogger(__name__)


def parse_curve(path: Path) -> list[tuple[int, int]]:
    pts: list[tuple[int, int]] = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        t, p = line.replace(",", " ").split()
        pts.append((int(t), int(p)))
    pts.sort()
    if len(pts) < 2:
        raise ValueError(f"need at least 2 curve points in {path}")
    return pts


def interp(curve: list[tuple[int, int]], temp: int) -> int:
    if temp <= curve[0][0]:
        return curve[0][1]
    if temp >= curve[-1][0]:
        return curve[-1][1]
    for (t0, p0), (t1, p1) in zip(curve, curve[1:]):
        if t0 <= temp <= t1:
            f = (temp - t0) / (t1 - t0)
            return int(round(p0 + f * (p1 - p0)))
    return curve[-1][1]


def reset_all(handles_fans: list[tuple[object, int]]) -> None:
    for h, fan_idx in handles_fans:
        try:
            pynvml.nvmlDeviceSetDefaultFanSpeed_v2(h, fan_idx)
        except Exception as e:
            log.warning("reset fan %d failed: %s", fan_idx, e)


def main() -> int:
    conf = Path(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1] != "reset" else DEFAULT_CONF
    pynvml.nvmlInit()
    n = pynvml.nvmlDeviceGetCount()
    handles_fans: list[tuple[object, int]] = []
    for i in range(n):
        h = pynvml.nvmlDeviceGetHandleByIndex(i)
        for f in range(pynvml.nvmlDeviceGetNumFans(h)):
            handles_fans.append((h, f))

    if len(sys.argv) > 1 and sys.argv[1] == "reset":
        reset_all(handles_fans)
        log.info("reset to default curve on %d fans", len(handles_fans))
        pynvml.nvmlShutdown()
        return 0

    curve = parse_curve(conf)
    log.info("curve from %s: %s", conf, curve)
    log.info("controlling %d GPUs / %d fans", n, len(handles_fans))

    stop = False

    def _shutdown(signum, frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    last_set: dict[tuple[int, int], int] = {}

    try:
        while not stop:
            for i in range(n):
                h = pynvml.nvmlDeviceGetHandleByIndex(i)
                temp = pynvml.nvmlDeviceGetTemperature(h, pynvml.NVML_TEMPERATURE_GPU)
                target = interp(curve, temp)
                for f in range(pynvml.nvmlDeviceGetNumFans(h)):
                    key = (i, f)
                    prev = last_set.get(key, -100)
                    if abs(target - prev) >= HYSTERESIS:
                        try:
                            pynvml.nvmlDeviceSetFanSpeed_v2(h, f, target)
                            last_set[key] = target
                            log.info("GPU%d fan%d -> %d%% (T=%dC)", i, f, target, temp)
                        except pynvml.NVMLError as e:
                            log.error("set GPU%d fan%d failed: %s", i, f, e)
            time.sleep(POLL_INTERVAL)
    finally:
        reset_all(handles_fans)
        log.info("restored default curve, exiting")
        pynvml.nvmlShutdown()

    return 0


if __name__ == "__main__":
    sys.exit(main())
