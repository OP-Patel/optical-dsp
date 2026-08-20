# Milestone 08 evidence

Automated evidence was prepared on 2026-08-17 with Vivado and Vivado Simulator
2026.1. Physical BPW34 characterization was completed on 2026-08-19,
America/Toronto, with one explicit repeatability follow-up.

## Implemented test path

`bpw34_characterization_top` combines the Milestone 04 transmitter, guarded
JA4 laser output, A0 XADC acquisition, 1,024-sample capture RAM, packet/CRC
encoder, and USB-UART output. SW3 selects 1 or 10 kbit/s without rebuilding.

The host characterization command saves collision-resistant labeled CSV/JSON
pairs, checks sample integrity, records SHA-256 and physical metadata, computes
level/noise comparisons, and estimates training transition duration. It also
prints the expected switch settings before a capture.

## Automated verification

| Check | Result |
|---|---|
| Updated XADC controller simulation | PASS, 1,533 checks; 304 valid samples and 307 DRP requests |
| Extended startup EOC regression | PASS; a four-clock EOC level generated one request and no false fault |
| Python unit tests | PASS, 15 tests |
| Python syntax compilation | PASS |
| Routed timing | PASS; setup WNS `+3.695 ns`, hold WHS `+0.114 ns`, zero failing endpoints |
| DRC | PASS; zero checks and zero bitstream DRC errors |
| Utilization | 369 LUTs, 589 registers, one RAMB18E1, one XADC |
| Bitstream generation | PASS |
| Programming command dry run | PASS; Vivado path, Tcl script, bitstream, and device selector resolved |

## Prepared bitstream

```text
artifacts/bitstreams/bpw34_characterization_top.bit
SHA-256 BBE292C9EF3247229BE6376956ECA750D4E5B59ABAFE441C1F301935FD252BCD
```

Build evidence:

- `artifacts/logs/20260817-131622-build.log`
- `artifacts/reports/milestone-08-utilization.rpt`
- `artifacts/reports/milestone-08-timing-summary.rpt`
- `artifacts/reports/milestone-08-drc.rpt`
- `artifacts/logs/milestone-08-tb-xadc-controller.log`

## Physical status

`PASS WITH FOLLOW-UP`

| Item | Accepted result |
|---|---|
| Detector | `pd02` selected over `pd01` |
| External load | 100 kΩ; effective load dominated by the onboard A0 divider |
| Geometry | 7.4 cm separation; transmitter and detector approximately 2 cm above the supporting surface |
| DC evidence | Ten OFF and ten ON captures; aggregate means 13.660 and 16.086 codes |
| DC separation | 2.425 codes; every paired run positive, range 2.054–2.652 |
| 1 kbit/s | PASS; ten captures, mean fitted separation 2.527 codes |
| 10 kbit/s | PASS; ten captures, 42–43 fitted transitions each, mean separation 2.390 codes |
| Blocked path | PASS; fitted separation fell to 0.176 codes, a 92.6% reduction |
| Integrity | Every packet passed CRC; every capture contained 1,024 consecutive samples; no rail clipping |

The accepted raw evidence is under
`artifacts/captures/milestone-08/`. Detailed values and the selected wiring are
in `docs/hardware/optical-afe-selection.md`.

The setup was not dismantled and rebuilt three times. That mechanical
realignment test, exact room-light description, and beam-stop record remain
qualification follow-ups and are not claimed as completed.
