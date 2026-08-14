# Milestone 06 evidence

The XADC acquisition RTL, behavioral model, testbench, constraints, routed
implementation, and bitstream are complete. Physical DC-input calibration and
sample-rate measurement remain pending.

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

## Physical evidence still required

- Program `xadc_bringup_top.bit` with A0 initially grounded through the planned
  safe test connection.
- Confirm LD4 (`sample_seen_led`) turns on and LD6 (`xadc_fault_led`) stays off.
- Apply at least two measured DC voltages in the A0 0-3.3 V range.
- Record mean, minimum, maximum, and sample count in
  `docs/hardware/xadc-interface.md`.
- Measure the real `sample_valid` rate over a known interval.
- Do not attach the BPW34 until these electrical checks pass.
