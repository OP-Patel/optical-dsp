# Milestone 06 partial completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `06 — Single-channel XADC acquisition` |
| Date prepared | 2026-08-13, America/Toronto |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware status | Routed bitstream ready; known-voltage A0 test not yet performed |

## What was implemented

- A vendor-independent two-state DRP controller with a sticky timeout/overrun
  fault and normalized sample-stream interface.
- A direct 7-series `XADC` primitive adapter configured for physical A0/VAUX4,
  single-channel continuous unipolar conversion, no sample averaging, and a
  clock divider of 16.
- A deterministic XADC behavioral model and self-checking testbench.
- A bring-up top with sample-seen, activity, sticky-fault, and half-scale LEDs.
- A0 analog constraints, a reproducible routed build, and a generated bitstream.

## Stream contract

| Signal | Contract |
|---|---|
| `sample_u12` | New conversion result from DRP `DO[15:4]` |
| `sample_valid` | Exactly one 100 MHz clock for each accepted DRP result |
| `sample_index` | First sample zero; advances once per valid sample; natural unsigned rollover |
| `xadc_busy` | One DRP result read is outstanding |
| `xadc_fault` | Sticky timeout, overrun, unexpected response, or illegal-state indication; reset clears it |

## Configuration

| Setting | Value |
|---|---|
| Board input | A0 |
| Auxiliary channel | VAUX4, ADC channel 20 |
| DRP result address | `7'h14` |
| `INIT_40` | `16'h0014` |
| `INIT_41` | `16'h3000` |
| `INIT_42` | `16'h1000` |
| DCLK / ADCCLK | 100 MHz / 6.25 MHz |
| Expected conversion rate | Approximately 240,385 samples/s before physical measurement |

## Automated results

| Test | Observed | Pass? |
|---|---|---|
| Controller/model testbench | Exact edge codes, variable latency, 300-sample continuity/rollover run, timeout, overrun, and reset cancellation | Yes |
| Simulation checks | 1,531 checks | Yes |
| Routed timing | WNS `+6.494 ns`, WHS `+0.249 ns`, zero failing endpoints | Yes |
| DRC | Zero checks and zero bitstream DRC errors | Yes |
| Utilization | 32 LUTs, 34 flip-flops, 0 latches, one XADC | Yes |

## Prepared bitstream

```text
artifacts/bitstreams/xadc_bringup_top.bit
SHA-256 A9C816427C73F1FD16E10CA89620A595212771EA968D730E9D521EF9ADFF7C71
```

Build it again with:

```powershell
.\scripts\fpga.cmd build `
    -BuildScript scripts\build_xadc_bringup.tcl
```

Program it only when the A0 test connection is ready:

```powershell
.\scripts\fpga.cmd program `
    -Bitstream artifacts\bitstreams\xadc_bringup_top.bit
```

## Hardware follow-up

- [ ] Program the prepared bitstream with A0 initially at ground.
- [ ] Confirm sample-seen activity and no sticky acquisition fault.
- [ ] Apply and measure ground plus at least two known DC voltages.
- [ ] Record mean/minimum/maximum codes and confirm monotonic response.
- [ ] Measure the physical sample-valid rate.
- [ ] Complete `docs/hardware/xadc-interface.md` without estimated measurements.

## Reviewer decision

- Status: `RTL/SIMULATION/ROUTED BUILD PASS — PHYSICAL XADC CALIBRATION PENDING`
- RTL/build blocker: None.
- Safe next action: Perform the known-voltage A0 checks before connecting the
  BPW34 or treating the sample stream as calibrated.
