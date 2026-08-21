# Milestone 10 evidence and combined physical procedure

## Automated status

| Check | Result |
|---|---|
| Rounding/saturation unit test | PASS, 30 checks |
| FIR bit-exact test | PASS, 6,692 checks |
| Tap variants in simulation | PASS, 8 and 16 taps |
| Impulse order | PASS for identity, four-sample, and full-window banks |
| Valid gaps and 5/6-clock latency | PASS |
| Latency-matched exact bypass | PASS |
| Positive and negative saturation | PASS |
| Host regressions | PASS, 15 tests |
| Routed 8-tap wrapper | PASS; WNS `+2.109 ns`, WHS `+0.105 ns` |
| Routed 16-tap wrapper | PASS; WNS `+2.331 ns`, WHS `+0.074 ns` |
| Cumulative routed timing | PASS; WNS `+1.142 ns`, WHS `+0.010 ns` |
| Cumulative bitstream DRC | PASS; zero errors, 14 nonblocking DSP input-pipeline advisories |
| Cumulative utilization | 780 LUTs, 1,135 registers, 23 DSP48E1, one RAMB18E1, one XADC |
| Bitstream generation | PASS |

| Variant | LUTs | Registers | DSP48E1 | Registered latency |
|---:|---:|---:|---:|---:|
| 8 taps | 64 | 89 | 11 | 5 clocks |
| 16 taps | 81 | 143 | 23 | 6 clocks |

Both isolated variants and the cumulative image meet 100 MHz. The 14 `DPIP-1`
warnings recommend additional DSP input registers but have no related timing or
DRC violations; the deliberately registered tree already meets the constraint.

Variant reports:

- `artifacts/reports/milestone-10-fir8-utilization.rpt`
- `artifacts/reports/milestone-10-fir8-timing-summary.rpt`
- `artifacts/reports/milestone-10-fir16-utilization.rpt`
- `artifacts/reports/milestone-10-fir16-timing-summary.rpt`

Cumulative image:

```text
artifacts/bitstreams/fir_bringup_top.bit
SHA-256 F2C4ADDBEA359EB45C3A674CC088D2751A585BD56C9F80324004AC86222E7651
```

- `artifacts/logs/20260820-212430-build.log`
- `artifacts/reports/milestone-10-utilization.rpt`
- `artifacts/reports/milestone-10-timing-summary.rpt`
- `artifacts/reports/milestone-10-drc.rpt`

## One-session Milestone 09 and 10 physical test

Keep the accepted `pd02`, 100 kOhm, 7.4 cm geometry with both modules about 2
cm above the supporting surface. Program the cumulative image:

```powershell
.\scripts\fpga.cmd program `
    -Bitstream artifacts\bitstreams\fir_bringup_top.bit
```

Set `SW0=1`, `SW2=1`, `SW1=0`, and `SW3=1` for 10 kbit/s training. Press BTN0,
release it, and wait at least 40 ms. BTN3 cycles the view only while capture is
idle:

| RGB0 | Capture | Milestone |
|---|---|---:|
| Red | Raw unsigned XADC | 09 baseline |
| Green | Unsigned DC estimate | 09 estimator |
| Blue | Signed centered output plus 2048 | 09 result / 10 input |
| Cyan | Signed 16-tap filtered output plus 2048 | 10 result |

For each command, use BTN3 until the listed color is visible, then press BTN1
to arm and BTN2 to trigger:

```powershell
python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view raw `
    --output-dir artifacts\captures\milestone-09-10

python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view estimate `
    --output-dir artifacts\captures\milestone-09-10

python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view centered `
    --output-dir artifacts\captures\milestone-09-10

python host\characterize_bpw34.py capture COM4 `
    --detector pd02 --resistor-ohms 100000 `
    --condition training --rate 10000 --run 1 `
    --distance-cm 7.4 --capture-view filtered `
    --output-dir artifacts\captures\milestone-09-10
```

For blue and cyan CSV files, signed value equals `raw_code - 2048`. The JSON
metadata prints the already-decoded signed statistics.

## Physical acceptance record to fill

- LD7 remains off for all four accepted captures.
- All packets contain 1,024 consecutive samples and valid CRC.
- Centered mean is near zero after warm-up.
- Centered training retains alternating positive and negative structure.
- Filtered training retains the structure without unexpected clipping.
- Record centered versus filtered mean, standard deviation, range, and fitted
  training separation.
- Take one centered and one filtered beam-blocked capture with `--run 2` and
  document the block/unblock transient and recovery.

Milestones 09 and 10 remain physically pending until this table is filled from
saved capture evidence. No separate rewire or reprogram step is required.
