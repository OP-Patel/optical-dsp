# Milestone 09 evidence

## Automated status

The fixed-point DC-removal RTL and its integrated diagnostic capture image were
implemented on 2026-08-19. Physical before/after captures remain to be taken.

| Check | Result |
|---|---|
| Bit-exact Vivado simulation | PASS, 125,395 checks |
| Constant zero and midscale | PASS |
| 1000-to-3000 step | PASS |
| Alternating 1000/3000 OOK | PASS; both polarities retained |
| Slow ramp and random valid gaps | PASS |
| Clear and freeze controls | PASS |
| Alternating 0/4095 extremes | PASS; no wrap or estimator fault |
| Exact one-clock valid latency | PASS on every driven cycle |
| Python host regressions | PASS, 15 tests |
| Routed timing | PASS; setup WNS `+2.009 ns`, hold WHS `+0.094 ns` |
| Routed DRC | PASS; zero checks and zero bitstream DRC errors |
| Utilization | 520 LUTs, 723 registers, one RAMB18E1, one XADC |
| Bitstream generation | PASS |

The simulation command and transcript summary are recorded in
`tb_dc_removal.txt`.

```text
artifacts/bitstreams/dc_removal_bringup_top.bit
SHA-256 53E659BFA2D931B28D4FB8FCD57CCC8AD8815389EA488C497075D07D4396870E
```

Build evidence:

- `artifacts/logs/20260820-154517-build.log`
- `artifacts/reports/milestone-09-utilization.rpt`
- `artifacts/reports/milestone-09-timing-summary.rpt`
- `artifacts/reports/milestone-09-drc.rpt`

## Hardware capture plan

Keep the accepted `pd02`, 100 kOhm, 7.4 cm, approximately 2 cm-high setup. Wait
at least 40 ms after BTN0 reset before arming a steady-state capture.

Take matching 10 kbit/s training captures in these views:

1. raw: RGB0 red after reset;
2. estimate: press BTN3 once, RGB0 green;
3. centered: press BTN3 twice from reset, RGB0 blue.

```powershell
# Use the same physical condition for all three commands. Select the named
# RGB0 color before pressing BTN1, then press BTN2 when the command is waiting.
python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view raw `
    --output-dir artifacts\captures\milestone-09

python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view estimate `
    --output-dir artifacts\captures\milestone-09

python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view centered `
    --output-dir artifacts\captures\milestone-09
```

Use `--capture-view raw`, `estimate`, or `centered` in
`host/characterize_bpw34.py`. For a centered CSV, signed samples equal
`raw_code - 2048`; the JSON metadata also reports decoded centered statistics.

Repeat centered capture once while the beam is blocked and once immediately
after unblocking it. Accept hardware only when the centered steady-state mean
is near zero, the 10 kbit/s structure remains visible, and LD7 reports no
saturation/fault.
