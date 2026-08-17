# Milestone 06 evidence

The XADC acquisition RTL, behavioral model, testbench, constraints, routed
implementation, and bitstream are complete. Physical ground and nominal-board-
3V3 endpoint captures passed on 2026-08-17. Independent voltage accuracy and a
physical sample-rate measurement remain follow-up items, not functional
blockers for the passive Milestone 08 receiver screen.

## Automated verification

| Check | Result |
|---|---|
| DRP controller/model simulation | `PASS`; exact packing, variable response latency, one valid per conversion, index continuity/rollover, timeout, overrun, and reset cancellation |
| Routed timing | `PASS`; WNS `+6.494 ns`, WHS `+0.249 ns`, no failing endpoints |
| Routing | `PASS`; no failed, unrouted, or partially routed nets |
| DRC | `PASS`; zero checks found and zero bitstream DRC errors |
| Utilization | 32 LUTs, 34 flip-flops, 0 latches, one XADC primitive |

Simulation transcript:

- [`tb_xadc_drp_controller.txt`](tb_xadc_drp_controller.txt)

Build evidence:

- `artifacts/logs/20260813-214835-build.log`
- `artifacts/reports/milestone-06-utilization.rpt`
- `artifacts/reports/milestone-06-timing-summary.rpt`
- `artifacts/reports/milestone-06-drc.rpt`
- `artifacts/bitstreams/xadc_bringup_top.bit`

Bitstream SHA-256:

```text
A9C816427C73F1FD16E10CA89620A595212771EA968D730E9D521EF9ADFF7C71
```

## Physical endpoint evidence

- Ground: 1,024 consecutive samples, codes 11 through 16, mean 13.2988.
- Nominal board 3V3: 1,024 consecutive samples, codes 4067 through 4074, mean
  4070.5381.
- Both UART packets passed CRC and were decoded into CSV files.
- The nominal rail was not independently measured, so these results verify the
  endpoint behavior but do not constitute precision calibration.
- Measure the real `sample_valid` rate over a known interval.
