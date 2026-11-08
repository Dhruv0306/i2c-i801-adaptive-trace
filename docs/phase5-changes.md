# Phase 5: changes to the plan (report and demo)

## Facts the report must state

- The test kernel is `7.2.15-netquota`, built from the kernel.org tarball with `CONFIG_LOCKDEP=y`. It carries the name of the previous course project. Say so, and say that nothing in this project touches that code.
- The driver runs in interrupt mode. Timing resolution is set by interrupt latency; the 250 to 500 µs figure applies only to the polling experiment.
- Only one DIMM is installed. The only SMBus client is the `ee1004` device added by hand at `0x53`, because the kernel probes `0x50` and `0x51` on this two-slot board.
- Natural timeouts, lost arbitration and PEC errors were not observed. Say which classes were exercised and which were checked by reading the code.
- "No response" is counted as a failure for the mode switch. It is also the normal answer for absent addresses.
- The debugfs format is not a stable interface.

## Demo script

1. Quiet bus: periodic `eeprom` reads, `mode` shows basic.
2. `i2cdetect -y -r 4`, then show `mode` switch to detailed and the scan in `trace`.
3. More `eeprom` reads until `mode` returns to basic.
4. Show `stats` and the histogram.

## Before publishing logs

Mask the DIMM serial number in `logs/baseline/t8-decode-dimms.txt` and in any later capture of `decode-dimms`. Check `dmesg` captures for usernames and home paths.
