# Milestone 08 completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `08 — BPW34 analog-link characterization` |
| Date completed | 2026-08-19, America/Toronto |
| FPGA target | Digilent Arty A7-100T, `xc7a100tcsg324-1` |
| Tools | Vivado and Vivado Simulator 2026.1; Python host utilities |
| Status | `PASS WITH FOLLOW-UP` |

## Final V1 selection

| Item | Frozen value |
|---|---|
| Photodiode | `pd02` |
| Photodiode connection | Cathode to Arty 3V3; anode to A0 sense node |
| External load | 100 kΩ from sense node to ground |
| Effective load | Dominated by the Arty A0 onboard 2.32 kΩ/1 kΩ divider |
| Optical distance | 7.4 cm |
| Mounting height | Approximately 2 cm above the supporting surface |
| Transmit rates | 1 kbit/s bring-up and 10 kbit/s qualification |

## What was implemented

- A combined transmitter/XADC/capture/UART characterization image.
- Switch-selectable OFF, ON, TRAINING, and FRAMED modes at 1 or 10 kbit/s.
- Labeled CSV/JSON capture tooling with metadata, CRC validation, statistics,
  collision protection, and SHA-256 hashes.
- OFF/ON comparison tooling plus documented expected-pattern analysis of the
  saved training captures.
- An XADC EOC edge fix that prevents the extended startup indication from
  producing a false sticky fault.
- Correct board constraints, routed build script, wiring record, and analog
  selection record.

## Automated evidence

| Check | Result |
|---|---|
| XADC controller simulation | PASS, 1,533 checks |
| Python tests | PASS, 15 tests |
| Routed setup timing | WNS `+3.695 ns`, zero failing endpoints |
| Routed hold timing | WHS `+0.114 ns`, zero failing endpoints |
| DRC | Zero checks and zero bitstream DRC errors |
| Utilization | 369 LUTs, 589 registers, one RAMB18E1, one XADC |
| Bitstream | Generated successfully |

```text
artifacts/bitstreams/bpw34_characterization_top.bit
SHA-256 BBE292C9EF3247229BE6376956ECA750D4E5B59ABAFE441C1F301935FD252BCD
```

## Physical evidence

`pd01` produced a positive but small response. The selected `pd02` was then
tested with ten OFF captures, ten ON captures, ten 1 kbit/s training captures,
ten 10 kbit/s training captures, and one blocked 10 kbit/s capture.

| Test | Result |
|---|---|
| OFF/ON DC | Means 13.660/16.086; 2.425-code aggregate separation |
| Paired DC repeatability | Every run positive; 2.054–2.652-code separation |
| 1 kbit/s training | PASS; mean fitted separation 2.527 codes |
| 10 kbit/s training | PASS; 42–43 transitions per capture; mean separation 2.390 codes |
| Blocked path | PASS; fitted separation 0.176 codes, 92.6% below nominal |
| Capture integrity | All CRC valid, all indices consecutive, no rail clipping |

The blocked capture demonstrates that the recovered periodic signal traversed
the optical path rather than arising from electrical coupling.

## Accepted limitations and follow-up

- The absolute raw separation is small because the Arty A0 divider dominates
  the passive load. Later DSP must use the measured numeric envelope.
- The setup was not dismantled and rebuilt three times. Mechanical realignment
  repeatability remains a final-qualification follow-up.
- Exact ambient illumination and beam-stop construction were not recorded.
- The board 3V3 rail was not independently measured, so results are functional
  code-domain evidence rather than precision voltage or optical calibration.

## Reviewer decision

- Status: `PASS WITH FOLLOW-UP`
- RTL/build blocker: None.
- Physical blocker for Milestone 09: None.
- Safe next action: Implement fixed-point DC removal using the measured
  approximately 13–16-code nominal input range while retaining full 12-bit
  safety behavior.
