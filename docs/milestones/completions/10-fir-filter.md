# Milestone 10 implementation report

## Identity

| Field | Value |
|---|---|
| Milestone | `10 - Readable fixed-point FIR filter` |
| Date implemented | 2026-08-20, America/Toronto |
| FPGA target | Digilent Arty A7-100T, `xc7a100tcsg324-1` |
| Hardware profile | `pd02`, 100 kOhm, 7.4 cm, 10 kbit/s |
| Status | `AUTOMATED AND ROUTED PASS - PHYSICAL EVIDENCE PENDING` |

## What I built

- A readable parameterized direct-form FIR with 8- and 16-tap verification.
- A fixed coefficient package containing identity, four-sample average,
  normalized full-window average, and saturation-test banks.
- A reusable symmetric rounding and signed saturation block.
- Exact-latency bypass, valid-gated history, safe-boundary bank loading, and a
  per-output saturation pulse.
- A cumulative diagnostic path whose cyan view captures the 16-tap output while
  retaining the three Milestone 09 views.
- One combined physical procedure so Milestones 09 and 10 can be tested without
  rewiring or changing bitstreams.

```text
signed s13 centered + valid
           |
           v
  16-sample delay line -> Q2.14 products -> signed 34-bit sum
                                                 |
                                  round + saturate to signed s16
                                                 |
            RAW / ESTIMATE / CENTERED / FILTERED capture selector
```

## Numeric contract

Q2.14 was selected because `16384` is exact unity. Products are signed 29-bit,
the accumulator is signed 34-bit, and output is signed 16-bit. The worst
available diagnostic bank stays within the accumulator bound. Rounding is
nearest with half cases away from zero; overflow saturates and pulses instead
of wrapping. Input-to-output latency is five clocks for 8 taps and six clocks
for 16 taps; filtered and bypass paths match within each configuration.

The hardware bank is the normalized 16-sample average. With about 24 measured
samples/symbol, it spans approximately two-thirds of one 10 kbit/s symbol.

## Automated verification

| Test | Observed | Pass? |
|---|---|---|
| Round/saturate boundaries | 30 checks | Yes |
| FIR reference comparison | 6,692 checks | Yes |
| 8/16-tap impulse order | Exact expected sequences | Yes |
| Constant and hand vector | Bit exact | Yes |
| Random vectors and gaps | Bit exact; history valid-gated | Yes |
| Bypass and bank boundary | Exact and latency matched | Yes |
| Saturation | Positive and negative pulses exact | Yes |
| Host regression | 15 tests | Yes |
| Routed 8-tap timing | WNS `+2.109 ns`, WHS `+0.105 ns` | Yes |
| Routed 16-tap timing | WNS `+2.331 ns`, WHS `+0.074 ns` | Yes |
| 8-tap wrapper utilization | 64 LUTs, 89 registers, 11 DSP48E1 | Yes |
| 16-tap wrapper utilization | 81 LUTs, 143 registers, 23 DSP48E1 | Yes |
| Cumulative routed timing | WNS `+1.142 ns`, WHS `+0.010 ns` | Yes |
| Cumulative bitstream DRC | Zero errors; 14 nonblocking `DPIP-1` advisories | Yes |
| Cumulative utilization | 780 LUTs, 1,135 registers, 23 DSP48E1, one RAMB18E1, one XADC | Yes |
| Bitstream | Generated successfully | Yes |

```text
artifacts/bitstreams/fir_bringup_top.bit
SHA-256 F2C4ADDBEA359EB45C3A674CC088D2751A585BD56C9F80324004AC86222E7651
```

## Hardware verification still required

Run `docs/evidence/milestone-10/README.md`. It collects the remaining Milestone
09 raw/estimate/centered evidence and the Milestone 10 filtered evidence in one
programming and wiring session.

## Problem found during implementation

The first direct-form version accumulated products through a linear 16-adder
chain. A board-constrained placement reported estimated `WNS=-12.924 ns`, so
that run was stopped and is not presented as passing evidence. The filter now
registers all products and every balanced-adder-tree level. This changes the
declared latency to five clocks for 8 taps and six clocks for 16 taps without
changing throughput; the bit-exact test retains both latency regressions.

## Reviewer decision

- Automated simulation: `PASS`
- Routed implementation: `PASS`
- Physical status: `PENDING`
- Safe next action: program the cumulative image, then collect
  all four views under the unchanged optical condition.
