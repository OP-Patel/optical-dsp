# Milestone 08 prepared evidence

Prepared on 2026-08-17 with Vivado and Vivado Simulator 2026.1. This records
the completed implementation and automated checks. BPW34 physical measurements
are intentionally still pending.

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

`PENDING` - no BPW34 result is claimed yet. Follow the measurement matrix in
`docs/milestones/08-bpw34-analog-link.md` and record the selected detector,
resistor, geometry, raw evidence, and rejected alternatives in
`docs/hardware/optical-afe-selection.md`.
