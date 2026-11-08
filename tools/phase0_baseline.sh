#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Phase 0: read-only checks and T1 baseline for the i2c-i801 project.
# Run as root. Writes to the bus: none. Only reads.

set -u
OUT="${1:-logs/baseline/phase0-$(date +%Y%m%d-%H%M%S).log}"
mkdir -p "$(dirname "$OUT")"
TREE="${KTREE:-/usr/src/linux-7.2.15}"

section() { printf '\n===== %s =====\n' "$1"; }

{
section "date / kernel"
date -Is
uname -a
uname -r

section "i801 driver messages (dmesg)"
dmesg | grep -i i801

section "SMBus PCI device and bound driver"
lspci -nnk -s 00:1f.4

section "i2c adapters"
i2cdetect -l
ls -l /sys/bus/i2c/devices

section "clients bound to the SMBus (modules)"
lsmod | grep -E 'i2c_i801|ee1004|spd5118|jc42|at24|i2c_smbus|iTCO|wdat'

section "memory type (decides the SPD driver)"
dmidecode -t memory | grep -E 'Type:|Speed|Locator:' | grep -v 'Bank'

section "kernel config: running kernel"
grep -E 'CONFIG_I2C_I801|CONFIG_DEBUG_FS=|CONFIG_I2C_SMBUS|CONFIG_LOCKDEP|CONFIG_DEBUG_KMEMLEAK|CONFIG_FTRACE=|CONFIG_TRACING=' \
    "/boot/config-$(uname -r)" 2>&1

section "kernel source tree: $TREE"
if [ -d "$TREE" ]; then
    ls -ld "$TREE"
    ls "$TREE" | head -30
    echo "--- git repo? ---"
    [ -d "$TREE/.git" ] && echo yes || echo "no (tarball)"
    echo "--- Makefile version ---"
    head -8 "$TREE/Makefile"
    echo "--- .config present? ---"
    ls -l "$TREE/.config" 2>&1
    echo "--- i801 driver in tree ---"
    ls -l "$TREE/drivers/i2c/busses/i2c-i801.c" 2>&1
    grep -n 'i801_access(struct\|SMBus using' "$TREE/drivers/i2c/busses/i2c-i801.c" 2>&1
else
    echo "NOT FOUND: $TREE"
    ls -d /usr/src/linux* 2>&1
fi

section "installed i2c_i801 module"
modinfo i2c_i801 2>&1 | grep -E 'filename|vermagic|version|srcversion'

section "watchdog users (must be empty before any reload)"
ls -l /dev/watchdog* 2>&1
fuser -v /dev/watchdog* 2>&1

section "debugfs mounted?"
mount | grep debugfs || echo "debugfs not mounted"

section "tools available"
for t in i2cdetect i2cget decode-dimms sensors dmidecode trace-cmd perf gcc make; do
    printf '%-12s' "$t"; command -v "$t" || echo MISSING
done

section "T1: read-only bus workload"
echo "(see step 2: run by hand after you choose a device address)"
} 2>&1 | tee "$OUT"

echo
echo "Log written to $OUT"