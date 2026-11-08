# Phase 4: changes to the plan (tests)

Changes to the test table in `plan.md` section 5. Tests not listed here stay as written.

## Setup that every reload test needs

1. Remove the client first: `echo 0x53 > /sys/bus/i2c/devices/i2c-4/delete_device`.
2. `rmmod i2c_i801`, then `insmod` the module built from the tree.
3. Add the client again: `echo ee1004 0x53 > /sys/bus/i2c/devices/i2c-4/new_device`. The kernel does not create it automatically on this board (see `phase0-findings.md`).
4. Find the bus by PCI address, not by number.

## T1: baseline

Add a tracepoint capture of one SPD read, using the core `smbus_*` events:

```bash
trace-cmd record -e smbus -o logs/baseline/t1-eeprom.dat \
    dd if=/sys/bus/i2c/devices/4-0053/eeprom of=/dev/null bs=512 count=1
trace-cmd report logs/baseline/t1-eeprom.dat > logs/baseline/t1-eeprom-trace.txt
grep -c smbus_result logs/baseline/t1-eeprom-trace.txt
```

The count is the reference for T2. Timing of a fixed workload comes from the Phase 2 tool, run on the stock module before the patched one is loaded.

## T2: counters

Use the measured count from T1 as the expected value. Run one read, then N reads, then compare the class counters with the tracepoint results.

## T5: overhead

The running kernel has `CONFIG_LOCKDEP=y`, which makes every spinlock slower. Overhead numbers are valid for this kernel only and the report must say so. Run the four configurations interleaved and repeated, report median and spread, and keep the machine otherwise idle. Tracepoint cost is measured on the same kernel.

## T7: reload cycles

`CONFIG_DEBUG_KMEMLEAK` is not set, so the leak check in the plan cannot run. Replace it with:

- `grep kmalloc /proc/slabinfo` before the first cycle and after the twentieth;
- confirm the debugfs directory is gone after `rmmod` and back after `insmod`;
- confirm `lsmod` shows no leftover references.

## T8: regression

Replace the `sensors` comparison (it shows no bus-4 data) with:

- `sha256sum /sys/bus/i2c/devices/4-0053/eeprom` must equal `80c4c2ad97689a11f1370ee3a24e485ae1c90ab5319114e55e921ba1ffe95c0e`;
- `decode-dimms` output identical to the baseline apart from the masked serial line;
- no new i801 or i2c lines in dmesg.

## T9: error injection

Still optional. Without it, timeout, lost arbitration and PEC are checked by reading the code only, and the report says so. Natural "no response" results come from the bus scan and the page-select probe.

## T10: static checks

Build with `make W=1 drivers/i2c/busses/i2c-i801.ko`, run `make C=2` for sparse on the file, and run `scripts/checkpatch.pl --strict` on each patch.

## New T11 (optional): polling versus interrupt

Run the T2 workload and the histogram capture with the default setup and with `disable_features=0x10` (steps in `phase2-changes.md`). Compare the histograms.
