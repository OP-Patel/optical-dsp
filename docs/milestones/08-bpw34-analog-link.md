# Milestone 08 — BPW34 analog-link characterization

**Depends on:** [Milestone 05](05-laser-and-daoki-bringup.md),
[Milestone 06](06-xadc-acquisition.md), and
[Milestone 07](07-capture-buffer-and-uart.md)

**Produces:** The selected V1 detector, load resistance, fixed geometry, signal
range, and verified 1/10 kbit/s analog path

## What this milestone does

Milestone 7 proved the A0-to-CSV path at the electrical endpoints. Milestone 8
uses that same path to screen the five BPW34-style detectors and choose one
passive receiver configuration. This is measurement and selection work, not a
new DSP design.

Final status (2026-08-19): `PASS WITH FOLLOW-UP`. The selected configuration is
`pd02`, a 100 kΩ external load, 7.4 cm transmitter-to-detector separation, and
both devices mounted approximately 2 cm above the supporting surface. Repeated
stationary 1 and 10 kbit/s training passed. A blocked-path capture removed
92.6% of the fitted 10 kbit/s pattern. Rebuild-from-scratch realignment remains
a documented follow-up.

## Starting circuit

```text
Arty 3V3 ---------------- BPW34 cathode
                          BPW34 anode
                               |
                               +---------- Arty A0
                               |
                             10 kΩ
                               |
Arty GND ----------------------+---------- KY-008 ground
```

The photodiode anode, resistor, and A0 meet at one sense node. Do not connect
the anode directly to ground. Start with 10 kΩ. Use only this passive, 3.3 V
bounded circuit until measurements justify a different front end.

The purchased devices are unverified BPW34-compatible parts. Label them
`pd01` through `pd05` and verify each device's physical orientation instead of
assuming every package has trustworthy markings.

## Combined FPGA image

`rtl/top/bpw34_characterization_top.sv` combines the permanent transmitter,
XADC capture, packet, and UART components:

```text
switches -> framer -> output guard -> JA4 -> KY-008
A0 -> XADC -> capture RAM -> packet/CRC -> UART -> Python
```

Build and program it with:

```powershell
.\scripts\fpga.cmd build `
    -BuildScript scripts\build_bpw34_characterization.tcl

.\scripts\fpga.cmd program `
    -Bitstream artifacts\bitstreams\bpw34_characterization_top.bit
```

### Physical controls

| Control | Function |
|---|---|
| BTN0 | Reset and clear sticky capture status |
| BTN1 | Arm an empty 1,024-sample capture |
| BTN2 | Trigger the armed capture |
| SW0 | Final laser-output enable |
| SW1 | Transmit mode bit 0 |
| SW2 | Transmit mode bit 1 |
| SW3 | Symbol rate: `0` = 1 kbit/s, `1` = 10 kbit/s |

Mode is `{SW2, SW1}`:

| SW2 | SW1 | Mode |
|---:|---:|---|
| 0 | 0 | OFF |
| 0 | 1 | ON |
| 1 | 0 | TRAINING |
| 1 | 1 | FRAMED |

Change SW1–SW3 only while SW0 is off. Then set SW0 on when the intended mode
and rate are visible on the switches.

### Status LEDs

| LED | Meaning |
|---|---|
| LD4 | Capture armed |
| LD5 | Capture RAM actively filling; it lasts only about 4.3 ms |
| LD6 | Capture complete/frozen or being transmitted |
| LD7 | Sticky XADC, rejected-control, capture, or packet fault |

The XADC controller now recognizes an extended startup EOC as one event, so the
configuration-time false fault observed in Milestone 7 should no longer occur.
BTN0 still clears all state if LD7 is ever set.

## Labeled capture tool

`host/characterize_bpw34.py` creates deterministic filenames and JSON sidecars
containing the physical metadata, CRC result, sample statistics, consecutive
index result, and CSV SHA-256. It refuses to overwrite an existing run unless
`--force` is explicitly supplied. It checks that the condition/rate pairing is
valid and prints the exact SW0/SW2/SW1/SW3 values before opening the serial
port.

Example capture:

```powershell
python host\characterize_bpw34.py capture COM5 `
    --detector pd01 `
    --resistor-ohms 10000 `
    --condition dark `
    --rate 0 `
    --run 1 `
    --distance-cm 20 `
    --ambient "room lights on"
```

Start the command first. When it says it is waiting, press BTN1 and then BTN2.
The default output directory is `artifacts/captures/milestone-08/`.

Supported condition labels are `dark`, `ambient`, `off`, `on`, `training`,
`blocked`, and `misaligned`. Rates are `0`, `1000`, and `10000`. The optional
25 kbit/s stretch rate is intentionally unavailable until a later image
explicitly adds and verifies it.

Summarize saved captures with:

```powershell
python host\characterize_bpw34.py summary `
    artifacts\captures\milestone-08\pd01_r10000ohm_off_dc_run01.csv `
    artifacts\captures\milestone-08\pd01_r10000ohm_on_dc_run01.csv
```

Compare OFF, ON, and training captures with:

```powershell
python host\characterize_bpw34.py compare `
    --off artifacts\captures\milestone-08\pd01_r10000ohm_off_dc_run01.csv `
    --on artifacts\captures\milestone-08\pd01_r10000ohm_on_dc_run01.csv `
    --training artifacts\captures\milestone-08\pd01_r10000ohm_training_1000bps_run01.csv `
    --output artifacts\reports\pd01-r10000-comparison.json
```

Add `--plot-dir artifacts/plots/pd01-r10000` to generate an OFF/ON histogram
and raw training plots. Plotting is optional and requires:

```powershell
python -m pip install matplotlib
```

The comparison report calculates:

```text
separation = mean_on - mean_off
pooled_noise = sqrt(std_off² + std_on²)
simple_quality = separation / pooled_noise
```

It also estimates 10–90% rising and falling transition times from each supplied
training capture. This is a relative engineering metric, not calibrated optical
SNR.

## Phase A — select the detector

Keep the distance, alignment fixture, 10 kΩ resistor, room lighting, capture
length, and KY-008 unchanged. For each `pd01` through `pd05`, collect:

1. `dark`: detector physically covered, laser disabled.
2. `ambient`: uncovered under the declared room lighting, laser disabled.
3. `off`: aligned geometry with laser disabled.
4. `on`: aligned laser continuously on.
5. `training`: aligned alternating laser at 1 kbit/s.

Use a unique detector and run number in every command. Do not retain only the
cleanest trace. The operator compared `pd01` and `pd02` and selected `pd02`
after ten paired OFF/ON runs. The remaining devices need to be screened only if
the selected device fails the rate tests. Base selection on:

- positive, repeatable ON/OFF separation;
- low pooled noise;
- no unexplained codes at 0 or 4095;
- clean 1 kbit/s transitions; and
- low sensitivity to small realignment.

## Phase B — effective load and rate check

The [official Arty A7 schematic](https://digilent.com/reference/_media/programmable-logic/arty-a7/arty-a7-e2-sch.pdf)
shows that each chipKIT analog input is already scaled by a 2.32 kΩ/1 kΩ
network. Seen from external A0, this creates an
approximately 3.32 kΩ DC path to ground before any external load is added. An
external load therefore appears in parallel with the board network:

```text
10 kΩ || 3.32 kΩ  = approximately 2.49 kΩ
100 kΩ || 3.32 kΩ = approximately 3.21 kΩ
```

This explains why the measured 10 kΩ-to-100 kΩ change was much smaller than a
tenfold change. Use 100 kΩ for the remaining passive tests because it disturbs
the onboard load least. Do not spend time testing the available 1 kΩ and 2 kΩ
parts; both reduce the effective load and expected signal.

For the selected detector collect:

1. OFF DC.
2. ON DC.
3. TRAINING at 1 kbit/s (`SW3=0`).
4. TRAINING at 10 kbit/s (`SW3=1`).
5. One blocked-path and one repeatable misalignment capture.

The external resistor is no longer treated as the main transimpedance element.
If every detector remains weak, document the passive A0 path as the measured
limitation rather than continuing an ineffective resistor sweep.

## Phase C — rebuild repeatability follow-up

For the selected detector, resistor, distance, and lighting policy:

1. Remove or deliberately misalign the detector.
2. Rebuild the declared nominal alignment from scratch.
3. Capture OFF, ON, and 10 kbit/s training.
4. Repeat the realignment and capture sequence three times.

Record all three runs in `docs/hardware/optical-afe-selection.md` and freeze the
geometry only if they remain consistent. This procedure was not completed in
the Milestone 08 session and is carried forward as a qualification follow-up;
it is not reported as performed.

## Safety and acceptance

- Begin wiring with SW0 off and mode OFF.
- Use only the 3V3 rail, never 5V or VU, for the passive detector bias.
- Confirm the resistor is present before enabling the laser.
- If a capture reaches 0 or 4095, stop and explain the clipping before changing
  resistance or alignment.
- If illumination reduces rather than increases the sense code, disconnect and
  recheck photodiode orientation; do not invert the result in RTL.
- A multimeter or oscilloscope is still required before connecting any future
  active or externally powered analog front end to A0.

## Done when

- [x] At least two detectors were compared consistently and one was selected.
- [x] The selected detector produced a repeatable 1 kbit/s alternating pattern.
- [x] Blocking the path removed the fitted 10 kbit/s optical pattern.
- [x] One detector/load/geometry is frozen for V1.
- [x] 10 kbit/s training transitions were captured without unsafe voltage or
  unexplained clipping.
- [x] Nominal conditions were repeated ten times at both rates and one blocked
  degraded capture was retained.
- [ ] The setup was rebuilt and realigned from scratch three times; deferred to
  final qualification.
- [x] `docs/hardware/optical-afe-selection.md` is complete enough to rebuild
  the circuit.

## Scope guard

Do not optimize for 25 kbit/s at the expense of completing 10 kbit/s. Do not
add an op-amp, automatic gain control, multiple analog boards, or a custom PCB
unless every available passive configuration fails the documented 1 kbit/s
screening test.
