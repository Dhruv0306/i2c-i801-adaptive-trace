# Phase 0: findings

Date: 2026-11-08. Everything here comes from the Phase 0 logs in `logs/baseline/` and from reading the `v7.2.15` sources.

`plan.md` and `handoff.md` are the original design documents and are not edited. Where a later `phaseN-changes.md` file disagrees with them, the phase file wins.

## Machine and kernel

| Item | Value |
|---|---|
| Running kernel | `7.2.15-netquota`, built from `/usr/src/linux-7.2.15` on 2026-11-03 |
| Source tree | kernel.org tarball, not a git repository; `.config` and `Module.symvers` present |
| Tree vs running kernel | `.config` is identical to `/boot/config-7.2.15-netquota`; module vermagic matches |
| `i2c-i801.c` | sha256 `752d89228a166ec26ee11ccebe094896b8ded3600df9da3b998b825bf98b80d0`, same as the `v7.2.15` stable tag, so the file is unmodified |
| Relevant config | `I2C_I801=m`, `I2C_I801_MUX=y`, `DEBUG_FS=y`, `TRACING=y`, `LOCKDEP=y`, `DEBUG_KMEMLEAK` not set, `EEPROM_EE1004=m` |
| Tools present | `trace-cmd`, `perf`, `gcc`, `make`, `i2c-tools`, `lm-sensors` |

## SMBus controller

- PCI `00:1f.4`, Alder Lake-S PCH `8086:7aa3`, driver `i801_smbus`, adapter `i2c-4`.
- dmesg: `SMBus using PCI interrupt` and `SPD Write Disable is set`. The driver runs in interrupt mode, not polling mode.
- `/dev/watchdog*` does not exist, so reloading `i2c_i801` has no watchdog side effect here.
- Before any client driver was added, `i2c_i801` had zero users and the bus carried no traffic.

## Devices on bus 4

A read scan (`i2cdetect -y -r 4`) answered at `0x30`, `0x35`, `0x36`, `0x44` and `0x53`. Only `0x53` is identified: it is the SPD EEPROM of the single installed DDR4 module (16 GB, DIMM1). The other four are unidentified and are not touched by the project.

## Why the SPD device did not appear by itself

The I2C core creates SPD clients in `i2c_register_spd()`. It probes only `0x50 + n` for `n` below the DMI slot count. This board reports two slots, so only `0x50` and `0x51` are probed, and the module answers at `0x53`. `modprobe ee1004` therefore has nothing to bind to.

Workaround, needed after every boot and after every reload of `i2c_i801`:

```bash
echo ee1004 0x53 > /sys/bus/i2c/devices/i2c-4/new_device
```

This creates `4-0053`, plus `4-0036` and `4-0037`, the page-select clients that `ee1004` adds itself.

## SPD baseline (for the regression test)

- `sha256sum /sys/bus/i2c/devices/4-0053/eeprom` = `80c4c2ad97689a11f1370ee3a24e485ae1c90ab5319114e55e921ba1ffe95c0e`, identical on two runs.
- `decode-dimms` output saved as `logs/baseline/t8-decode-dimms.txt`; both SPD CRCs report OK.
- The module's serial number appears in that file. Mask it before committing:

```bash
sed -i 's/^\(Assembly Serial Number *\).*/\1[masked]/' logs/baseline/t8-decode-dimms.txt
```

## Not done in Phase 0

- Timing of a fixed read workload. A shell loop would measure process start-up, so this waits for the Phase 2 workload tool.
- Tracepoint baseline of one SPD read. Do it once before Phase 1 (commands in `phase4-changes.md`, test T1).

## Dropped from the baseline

`sensors` shows only the NVMe drive, the CPU, ACPI and a fan. No chip on bus 4 appears in it, so it cannot detect a regression in this driver. It is no longer part of T8.
