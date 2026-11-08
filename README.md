# i2c-i801-adaptive-trace

Statistics and adaptive transaction tracing for the Linux `i2c-i801` driver, the SMBus host controller driver for Intel chipsets.

Course project for Advanced Operating Systems (CS G623), Ahmedabad University. Target kernel: **7.2.15**. Test hardware: Intel Alder Lake-S PCH, PCI `00:1f.4`.

> **Status: planning.** The design is written and the driver source has been checked against the `v7.2.15` tag. No code has been written, built or run yet. This README describes what the project will do, and will be updated as each phase lands.

## Why

`i2c-i801` runs every SMBus transaction on the machine: memory module SPD chips, hardware-monitoring chips, and anything else on that bus. Today the driver keeps no record of how those transactions go. It logs one line for a hardware failure, a few debug lines for other errors, and nothing else. There are no counts, no timing, and no breakdown of why a transaction failed.

## What it adds

1. **Counters.** Transactions by SMBus size and direction. Results by class: success, timeout, hardware failure, PEC error, no response, lost arbitration, busy. Completions by interrupt or polling. Block-buffer versus byte-by-byte use.
2. **Latency histogram.** Time from after `i801_check_pre()` to after `i801_check_post()`, in power-of-two buckets starting near 128 µs, with minimum, maximum and mean.
3. **Adaptive trace.** Normally only the cheap counters run. When errors cluster, the driver switches to detailed mode and records each transaction, including the controller's raw status bits, into a ring buffer of 256 records. It returns to basic mode once the bus is clean again.

### Adaptive modes

| Mode | What runs | Moves on when |
|---|---|---|
| Basic | Counters and histogram | `K` failures in the last `N` transactions, any timeout, or a transaction over a time limit |
| Detailed | Counters, histogram and trace ring | `M` clean transactions in a row |

Starting values: `N = 32`, `K = 4`, `M = 64`. These are to be tuned on the real machine and can be changed at run time.

## Design rules

- Hooks live in `i801_access()`, the single entry point for every SMBus transaction.
- The interrupt handler is not touched. All recording happens in process context.
- No transaction's behaviour or return value changes.
- Errors are classified from the errno that `i801_check_post()` already produces, plus the raw status bits.
- Time is measured in the hardware part of the transaction, not the wait for the mutex or runtime PM.
- debugfs is used on purpose: this is diagnostic data with no stable-interface promise.

## Interface

```
/sys/kernel/debug/i2c-i801/<pci address>/
├── stats        counters, error classes, histogram
├── trace        ring buffer contents, oldest first
├── mode         auto | basic | detailed
├── thresholds   N, K, M and the duration limit
└── reset        write to clear counters and the ring
```

A small user-space viewer (Python or shell) shows a live view: rates, error classes, the histogram and the current mode. A second script generates test workloads.

## Relation to the existing core tracepoints

The I2C core already provides SMBus tracepoints (`smbus_write`, `smbus_read`, `smbus_reply`, `smbus_result`). They carry the address, command, protocol and final result, but not the controller's status bits, and someone has to start tracing before the problem happens. This project complements them and does not replace ftrace. Test T4 compares the two, and T5 compares their cost.

## Repository layout (planned)

```
patches/      git format-patch series against v7.2.15
tools/        user-space viewer and workload script
docs/         plan.md, handoff.md, report
logs/         baseline and final run logs
```

## Build and test (proposed, not yet run)

```bash
cd /usr/src/linux-7.2.15
make olddefconfig && make modules_prepare
make drivers/i2c/busses/i2c-i801.ko
modinfo -F vermagic drivers/i2c/busses/i2c-i801.ko    # must match `uname -r`
sudo rmmod i2c_i801 && sudo insmod drivers/i2c/busses/i2c-i801.ko
ls /sys/kernel/debug/i2c-i801/
```

The module only loads if the source tree and config are the ones that built the running kernel. Otherwise a full kernel rebuild is needed.

**Safety:** use read operations on the bus only (`i2cdetect -y -r`, `i2cget`, `decode-dimms`, `sensors`). Never use `i2cset` or quick-write probing, and never write to the SPD addresses `0x50` to `0x57`. Before reloading `i2c_i801`, check that nothing holds `/dev/watchdog` open, because the reload removes the iTCO watchdog child device for a moment.

## Test plan

| # | Test |
|---|---|
| T1 | Baseline on the stock module |
| T2 | Counter correctness: reads of a present device, scan of absent addresses |
| T3 | Adaptive switching: scan, then clean reads |
| T4 | Cross-check against core `smbus_*` tracepoints |
| T5 | Overhead: stock, patched basic, patched detailed, stock with tracepoints |
| T6 | Concurrency with parallel readers, no lockdep warning |
| T7 | 20 unload/reload cycles, no oops or leak |
| T8 | Regression: `sensors` and `decode-dimms` output unchanged |
| T9 | Optional error injection for timeout, lost arbitration and PEC classes |
| T10 | `checkpatch.pl --strict`, `sparse`, `make W=1` |

## Known limitations

- In polling mode, timing resolution is about 250 to 500 µs because of the sleep in `i801_wait_intr()`.
- A healthy desktop bus rarely produces timeouts, lost arbitration or PEC errors. Without T9, those classes are verified by reading the code only.
- A bus scan produces many "no response" results by design and will trigger detailed mode.
- The debugfs format is not stable.
- Upstream acceptance is not a goal.

## Roadmap

- [ ] Phase 0: machine checks and T1 baseline
- [ ] Phase 1: counters, error classes, debugfs `stats`
- [ ] Phase 2: histogram and viewer
- [ ] Phase 3: adaptive mode and trace ring
- [ ] Phase 4: tests T2 to T10, overhead measurement
- [ ] Phase 5: report and demo

## Workflow

- Branches: `Dhruv_Patel/<feature-or-fix-name>`
- Commits are authored by Dhruv Rakeshbhai Patel, with a `Co-authored-by: Claude <noreply@anthropic.com>` trailer
- Changes are exchanged as `git format-patch` files and applied with `git am`

## License

The kernel driver is GPL-2.0-only, as is the rest of the Linux kernel. User-space tools in this repository are also released under GPL-2.0-only.

## Author

Dhruv Patel, B.Tech CSE, Ahmedabad University.
