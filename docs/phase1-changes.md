# Phase 1: changes to the plan (counters, error classes, debugfs `stats`)

## Source workflow

The kernel tree is a tarball, so `git format-patch` cannot run there. Use this flow:

1. First commit in this repository: the pristine `drivers/i2c/busses/i2c-i801.c` from the tree, at the same relative path. Check the sha256 in `phase0-findings.md` before committing.
2. Edit the file in the repository. Every later commit is a change to it.
3. `git format-patch` produces the series. Each patch has `From: Dhruv Rakeshbhai Patel <dpatel5469@gmail.com>`.
4. Apply to the tree with `patch -p1` from `/usr/src/linux-7.2.15`, or copy the file over.
5. Build only the module: `make drivers/i2c/busses/i2c-i801.ko`. Do not run `make olddefconfig`; the tree is already configured and built.
6. Keep the existing SPDX line in `i2c-i801.c`. Any new `.c` or `.h` file starts with `// SPDX-License-Identifier: GPL-2.0-only`.

## What the real traffic looks like

On this machine the only SMBus traffic is what we generate. Reading the `ee1004` sysfs file (`/sys/bus/i2c/devices/4-0053/eeprom`) produces, per `ee1004.c` on `v7.2.15`:

- SMBus byte read (`i2c_smbus_read_byte`) at probe, and on `0x36` to find the current page.
- SMBus byte write (`i2c_smbus_write_byte`, data `0x00`) to `0x36` or `0x37` to select a page.
- I2C block reads (`i2c_smbus_read_i2c_block_data`), up to 32 bytes each, within one 256-byte page.

So the size counters must keep `I2C_SMBUS_BYTE` and `I2C_SMBUS_I2C_BLOCK_DATA` as separate entries, not fold them into `BLOCK_DATA`. Index the array by the `size` argument of `i801_access()` and make it large enough for the highest `I2C_SMBUS_*` size constant.

## A "no response" is not always a fault

`ee1004_get_current_page()` reads `0x36`. A NACK there is the normal answer when page 1 is selected, and the driver treats `-ENXIO` as information. Keep `-ENXIO` as its own class and label it "no response" in `stats`, not "error". Phase 3 decides whether it counts towards the switch to detailed mode.

## Check before moving on

The counters from a known workload must match the tracepoint baseline from test T1 (transaction count and sizes). Do this before writing any histogram code.
