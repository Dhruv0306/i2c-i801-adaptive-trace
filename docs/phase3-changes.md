# Phase 3: changes to the plan (adaptive mode and trace ring)

## Which failures count towards the switch

Decision for this project: every non-success result counts towards the `K` of `N` window, including "no response" (`-ENXIO`). Reason: a healthy desktop bus almost never produces timeouts, lost arbitration or PEC errors, so excluding "no response" would leave detailed mode with nothing to trigger it except error injection. The scan demo depends on it. The report must state this choice and that "no response" is a normal answer for absent addresses and for a page-select probe.

## Expected numbers for the demo

- `i2cdetect -y -r 4` probes `0x03` to `0x77`, which is 117 addresses. Addresses that already have a kernel client (`0x36`, `0x37`, `0x53` once `ee1004` is added) are skipped by `i2cdetect`, as far as I know its behaviour. With `0x30`, `0x35` and `0x44` answering, that leaves about 111 "no response" results. Check this against the tracepoint count before relying on it.
- A full read of the 512-byte `eeprom` file should be about 17 or 18 transactions, going by `ee1004.c`: 8 block reads of 32 bytes per 256-byte page, plus one page-select write each time the file crosses to the other page. If page 0 is already selected, a read costs 17 (8 + 1 + 8). A read that starts with page 1 selected costs one more write, 18. Measure it in T1 and use the measured number to choose `M`.
- With `M = 64`, the return to basic mode needs a few clean `eeprom` reads. Tune `N`, `K` and `M` against the measured traffic, not against the starting values in the plan.

## Mode switch rules that stay as designed

Recording happens in process context only. The interrupt handler is not touched. The entry that caused the switch is the first record in the ring.
