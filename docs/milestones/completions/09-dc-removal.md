# Milestone 09 implementation report

## Identity

| Field | Value |
|---|---|
| Milestone | `09 - Fixed-point DC removal` |
| Date implemented | 2026-08-20, America/Toronto |
| FPGA target | Digilent Arty A7-100T, `xc7a100tcsg324-1` |
| Tools | Vivado and Vivado Simulator 2026.1; Python host utilities |
| Hardware | Accepted `pd02`, 100 kOhm, 7.4 cm path for pending captures |
| Status | `AUTOMATED PASS - PHYSICAL EVIDENCE PENDING` |

## What I built

- `dc_removal`: a valid-gated first-order DC estimator and signed subtractor.
- A bit-exact self-checking testbench with an independent integer model.
- `dc_removal_bringup_top`: the existing optical/XADC/UART path plus selectable
  raw, estimate, and centered diagnostic capture views.
- BTN3/RGB0 view selection with the chosen view frozen when BTN1 arms capture.
- Host capture labels and metadata that record which FPGA view was selected.
- A dedicated constraints file and routed-build script for the Milestone 09
  image.

```text
XADC u12 + valid -> Q12.10 DC estimator -> signed s13 centered stream
        |                    |                         |
        +--- RAW ------------+--- ESTIMATE ------------+--- CENTERED
                                      BTN3 capture mux -> RAM -> packet -> UART
```

## Numeric and interface decisions

`K=10` gives an estimator multiplier of 1/1024. The estimate is unsigned
Q12.10 in 22 bits, while subtraction and updates use explicit signed extensions.
The centered output is signed 13-bit and covers the complete -4095 to +4095
input difference. It is rounded to nearest with half cases away from zero and
has exactly one system-clock of latency. Estimator bounds saturate instead of
wrapping and set a sticky fault.

At 240384.615 samples/s the 1/e time constant is approximately 4.258 ms. A
40 ms post-reset wait covers roughly nine time constants and is the conservative
hardware warm-up instruction.

## Commands run

```powershell
C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat --sv `
  rtl\dsp\dc_removal.sv rtl\tb\tb_dc_removal.sv
C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat `
  tb_dc_removal -s tb_dc_removal_sim
C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat `
  tb_dc_removal_sim -runall
python -m unittest discover -s host\tests -v
.\scripts\fpga.cmd build `
  -BuildScript scripts\build_dc_removal_bringup.tcl
```

## Automated verification

| Test | Observed | Pass? |
|---|---|---|
| DC-removal bit-exact simulation | 125,395 checks | Yes |
| Constant settling | Midscale reached signed output within +/-1 code | Yes |
| Alternating OOK preservation | 128/128 low and 128/128 high checks retained polarity and margin | Yes |
| Valid gaps | Random idle clocks left estimate unchanged | Yes |
| Clear/freeze | Reset state and held estimator matched reference | Yes |
| Full-range safety | Alternating 0/4095 produced no wrap or fault | Yes |
| Host regression | 15 tests | Yes |
| Routed setup timing | WNS `+2.009 ns`, zero failing endpoints | Yes |
| Routed hold timing | WHS `+0.094 ns`, zero failing endpoints | Yes |
| Routed DRC | Zero checks and zero bitstream DRC errors | Yes |
| Utilization | 520 LUTs, 723 registers, one RAMB18E1, one XADC | Yes |
| Bitstream | Generated successfully | Yes |

```text
artifacts/bitstreams/dc_removal_bringup_top.bit
SHA-256 53E659BFA2D931B28D4FB8FCD57CCC8AD8815389EA488C497075D07D4396870E
```

## Hardware verification still required

- Capture the same 10 kbit/s training condition in raw and centered views.
- Show that steady-state centered mean is near zero without losing the pattern.
- Capture beam block/unblock transient and measure recovery time.
- Confirm LD7 stays off during accepted steady-state captures.

The RTL is ready to program, but Milestone 09 is not claimed physically complete
until these captures exist.

## Problem found during implementation

The first constant-midscale test used only about seven time constants and still
produced a rounded two-code residual. The test now runs for about nine time
constants and requires the documented +/-1-code result. This became the 40 ms
hardware warm-up rule.

## Reviewer decision

- Automated status: `PASS`
- Physical status: `PENDING`
- Safe next action: build/program the Milestone 09 image and collect the three
  view captures before closing the milestone.
