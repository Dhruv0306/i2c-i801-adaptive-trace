# Phase 2: changes to the plan (histogram and user-space tools)

## Timing limit

The 250 to 500 µs polling quantization in `plan.md` section 4.3 and section 7 does not apply to the default setup. The driver runs with a PCI interrupt, so the measured time is limited by interrupt wake-up latency. The polling limit applies only when polling is forced (see the optional experiment below).

## Bucket boundaries

Do not fix the boundaries at 128 µs yet. At a 100 kHz bus clock, a byte read should take roughly 200 µs and a 32-byte block read a few milliseconds. These are estimates; the clock rate on this machine is not confirmed. Capture raw durations from a first build (print them in the trace) and choose the buckets from that data.

## Optional experiment: polling versus interrupt

`disable_features=0x10` makes the driver skip interrupts. The parameter is read at probe, so it needs a reload:

```bash
rmmod i2c_i801
insmod drivers/i2c/busses/i2c-i801.ko disable_features=0x10
dmesg | tail -3          # expect: SMBus using polling
echo ee1004 0x53 > /sys/bus/i2c/devices/i2c-4/new_device
```

Run the same workload in both modes. The histogram should show the polling step directly, which turns the limit in the report from a claim into a measurement.

## Workload tool

`ee1004` owns `0x53`, so the tool must not open that address through `/dev/i2c-4`. Plan the workloads like this:

- Present device: read the `ee1004` `eeprom` file (`dd if=/sys/bus/i2c/devices/4-0053/eeprom of=/dev/null bs=512 count=N`). This is the main workload.
- Absent addresses: read-byte probes through `/dev/i2c-4`, on addresses that did not answer in the baseline scan.
- Parallel readers: several `dd` processes on the same file.

Only read operations. No `i2cset`, no quick-write probing, no writes to `0x50` to `0x57`.

Scripts start with `#!/...` and then `# SPDX-License-Identifier: GPL-2.0-only`. The workload tool replaces the shell loop that the first T1 plan mentioned.

## Viewer

It reads the debugfs files by PCI address (`/sys/kernel/debug/i2c-i801/0000:00:1f.4/`), not by bus number, because the bus number can change across reloads.
