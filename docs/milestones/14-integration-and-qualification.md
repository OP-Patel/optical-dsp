# Milestone 14 — Integration, qualification, and demo

**Time box:** 2 days for the baseline run; repeat only when a failed criterion
identifies a real defect
**Depends on:** All previous milestones
**Produces:** A timing-clean bitstream, repeatable physical benchmark, headless
evidence archive, and defensible project explanation

## Why this milestone exists

This milestone does not add a new algorithm. It proves that the permanent pieces
work together and that another person can reproduce the result from source,
hardware notes, and terminal commands. Integration is controlled by the
interfaces and tests already built, so it should not become a redesign cycle.

## Final top-level composition

```text
reset/timing
  -> PRBS/framer -> output guard -> transistor/DAOKI laser
  -> XADC -> capture tap -> DC removal -> FIR
  -> phase/threshold -> frame sync -> PRBS checker/BER counters
  -> snapshot/control/telemetry -> UART -> host command/logger tools
```

Keep named intermediate taps for raw XADC, DC-removed output, FIR output, and
decided bits. These are diagnostic selections, not parallel receiver designs.

## Integration order

Integrate in the same direction as data flow:

1. Build with TX in safe OFF mode and verify heartbeat/build ID/UART.
2. Verify XADC grounded capture and no sticky acquisition faults.
3. Enable TRAINING and run calibration at 1 kbit/s.
4. Enable FRAMED mode and acquire lock at 1 kbit/s.
5. Repeat at the 10 kbit/s qualification profile.
6. Compare filter bypass and selected filter using the same frozen channel
   condition and run length.
7. Exercise block/unblock, recalibration, capture, host disconnect, and recovery.
8. Run the declared benchmark matrix without changing acceptance rules.

When an integration failure appears, return to the failing module's unit test
and add a regression reproducing it. Do not patch around a broken interface only
in the top level.

## Final testbench and verification layers

### Automated RTL regression

Run every self-checking unit and integration test. Add one top-level simulation
that includes:

- behavioral optical/XADC sample source;
- training and framed mode;
- calibration;
- correct and corrupted payloads;
- status snapshot; and
- at least one UART command/status round trip.

It need not simulate millions of real 100 MHz cycles; use parameter overrides
that preserve event ordering while shortening divisors and payloads.

### Static/build checks

- synthesis and implementation complete from the terminal batch flow;
- WNS and WHS are non-negative for all declared clocks;
- no unconstrained endpoint or critical DRC remains;
- CDC report contains only understood structures;
- resource use is recorded by hierarchy;
- bitstream SHA-256, Git commit, dirty state, Vivado version, and board target
  appear in the build/run manifest; and
- the programming command verifies the connected `xc7a100t` before loading.

### Physical qualification matrix

| Test | Baseline acceptance |
|---|---|
| XADC continuity | 250 kSa/s for at least `1.5e8` samples/10 minutes with no discontinuity fault |
| Digital loopback | 0 errors in at least `1e6` PRBS payload bits |
| Nominal optical link | 10 kbit/s, at least `1e6` compared payload bits, report raw errors and confidence interval |
| Calibration | All 25 synthetic phases pass; physical phase/threshold repeat after three realignments |
| DSP comparison | Paired filter-off/on counts under the same frozen degraded condition; report result even if no improvement |
| Reacquisition | Restore lock within the declared bound after a 100-symbol block/interruption |
| Recovery stability | 25 start/calibrate/lock/interruption/relock cycles with no false lock or stuck state |
| Telemetry | 6,000 packets over 10 minutes with zero malformed packets and no unexplained sequence gaps |
| Host independence | Closing the command/logger process does not reset or stop hardware measurement |
| Capture integrity | Raw/DC/FIR capture metadata, CRC, count, and sample indices are valid |

For zero errors in `N` bits, report the one-sided 95% upper bound (`~3/N`). For
non-zero errors, report raw error and compared counts plus an exact binomial
confidence interval calculated by the host.

## Honest DSP comparison

Predeclare the nominal and degraded settings from Milestone 08. For filter-off
and filter-on runs:

- use the same hardware IDs, distance, resistor, rate, PRBS, warm-up, bit count,
  and ambient-light policy;
- alternate run order if drift is possible;
- log threshold/phase and any recalibration;
- keep raw numerator/denominator counts; and
- publish a neutral result if confidence intervals overlap.

The project succeeds as a learning prototype even if the FIR does not improve an
already clean link. Do not manufacture a 10x claim by choosing one favorable
short run. The stronger claim requires repeatable, statistically distinguishable
evidence.

## Demo script

Write a short, repeatable demonstration sequence:

1. Show the repository milestone map and hardware wiring.
2. Build/program from the VS Code terminal without opening Vivado.
3. Query build/hardware identity with the headless host utility.
4. Run calibration and explain chosen phase/threshold.
5. Start framed PRBS transmission and print or save lock/BER counters.
6. Save raw, DC-removed, and FIR sample captures for offline inspection.
7. Block the beam, show lock loss, unblock, and show reacquisition.
8. Toggle filter bypass/bank through an acknowledged command.
9. Stop and inspect the saved manifest/results.

Aim for five to eight minutes. Every visible number should have a definition you
can explain.

## Project explanation checklist

Be prepared to explain, in your own words:

- why OOK and oversampling were chosen;
- how the transistor protects FPGA I/O;
- why DAOKI digital RX and BPW34 analog RX have different roles;
- how XADC raw code becomes a signed DSP sample;
- fixed-point widths, rounding, saturation, and FIR coefficient effects;
- how training selects phase/threshold and the limit of the common clock;
- how frame synchronization differs from PRBS comparison;
- why BER requires a numerator, denominator, lock definition, and confidence;
- how coherent snapshots and transaction IDs keep the host honest;
- why the host command/logger tools are instrumentation rather than the receiver; and
- which upgrades measurements justify, versus features merely left out.

## Final repository evidence

Create or update:

```text
README.md                            headline measured result and reproduction
docs/architecture.md                final block/clock/reset/data contracts
docs/protocol.md                    optical and UART protocols
docs/hardware/*.md                  exact inventory, wiring, and selection
docs/milestones/completions/*.md    milestone learning/exit reports
docs/benchmarks/final-summary.md    methods, results, limits, plots
artifacts/runs/<run-id>/             ignored raw evidence with manifest/hashes
```

## Done when

- [ ] Every milestone completion checklist and regression passes.
- [ ] The terminal creates and programs a timing-clean identified bitstream.
- [ ] The 10 kbit/s physical qualification matrix is complete.
- [ ] CLI controls, capture, logging, and disconnect/reconnect work.
- [ ] Results include limitations and confidence, not only best-case screenshots.
- [ ] Another person can follow the README and reproduce the demonstration.
- [ ] You can explain every major block without reading the source line by line.

## Post-V1 upgrade backlog

Only after completion, evaluate measured reasons for:

- transimpedance amplifier;
- external ADC or faster optical module;
- independent-clock transmitter and stronger timing recovery;
- adaptive threshold/equalizer;
- Ethernet/UDP transport;
- custom PCB or enclosure; and
- higher line rates.

Each upgrade should preserve the existing stream/control contracts so V1 remains
a working reference rather than being discarded.
