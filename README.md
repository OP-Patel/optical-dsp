# Arty A7 optical DSP prototype

A student-scale FPGA optical-communications prototype for the Digilent Arty
A7-100T. The project will transmit a deterministic NRZ on-off-keyed (OOK) bit
stream through a short 650 nm laser link, sample a BPW34-style photodiode with
the Arty's built-in XADC, perform fixed-point receive DSP in FPGA fabric, and
measure the resulting bit-error rate (BER).

The goal is a reproducible proof of concept, not a high-speed or calibrated
optical instrument. It is also explicitly a learning project: the owner will
hand-write and explain the RTL, testbenches, and host tools. The
repository documentation supplies small interface contracts, design context,
hints, and verification targets rather than completed project logic.

The repository is currently in **planning and hardware bring-up preparation**;
no optical-link or DSP RTL has been implemented.

## Start here

- [Implementation-ready project plan](docs/project-plan.md) — scope, hardware,
  wiring gates, milestones, verification, benchmarks, risks, and repository
  organization.
- [14-step learning path](docs/milestones/README.md) — one permanent,
  independently testable addition every one or two workdays, ending with the
  qualified link and reproducible headless evidence.
- [Terminal Vivado workflow](scripts/README.md) — batch build/program commands
  that do not require opening the Vivado IDE.

## Learning and implementation policy

- Each milestone adds a reusable component or a permanent diagnostic path.
- Every RTL block gets a self-checking testbench before system integration.
- Milestone guides explain relevant SystemVerilog concepts and expected
  behavior, but you write the implementation and explain the design yourself.
- Fixes discovered during integration are first reproduced in the responsible
  module's testbench, preserving a regression instead of creating top-level
  patches.
- V1 is completed before optional redesigns such as a TIA, external ADC,
  independent transmitter, or Ethernet transport.
- A short completion note records what was built, how it was verified, what
  failed, and what you learned.

## Selected prototype hardware

| Role | Selected hardware | Purpose and limitation |
|---|---|---|
| FPGA and ADC | Digilent Arty A7-100T and its 12-bit, 1 MSa/s-capable XADC | A0-A5 accept an external 0-3.3 V signal through the board's scaling network; V1 does not require a separate ADC purchase. |
| Optical transmitter | DAOKI kit's KY-008-style 650 nm, nominal 5 mW laser module | Low-cost OOK source. Its actual pinout, current, switching bandwidth, and optical classification must be measured or verified after arrival. |
| First receiver | DAOKI non-modulated digital laser receiver module | Alignment, beam interruption, and very-low-rate digital bring-up only. Its comparator output is not an analog waveform and cannot demonstrate receive DSP. |
| DSP receiver | Amazon five-pack of through-hole BPW34/BPW34S-style silicon PIN photodiodes | Analog light detector for the XADC path. The seller is not Vishay, so the devices are treated as unverified BPW34-compatible parts and characterized before benchmarking. |
| Initial analog front end | BPW34-style detector, 3.3 V reverse bias, and 10 kΩ load resistor | Cheapest first experiment. Resistor values may be swept after measuring signal swing and bandwidth; a transimpedance amplifier is an optional later upgrade. |
| Laser control | KY-008 `S` supply/control pin driven by an Arty LVCMOS33 GPIO | This delivered variant uses `S` and ground while its middle pin is unused. Functional direct drive is confirmed; loaded voltage and GPIO current still require measurement. |

Selected purchase listings:

- [DAOKI four-transmitter/four-receiver kit](https://www.amazon.ca/dp/B091GBJLX5)
- [Five BPW34/BPW34S-style photodiodes](https://www.amazon.ca/dp/B0F4CNXCMX)

The DAOKI receiver and BPW34 are complementary, not substitutes. The DAOKI
receiver gets the optical path working quickly; the BPW34 path produces the
sampled amplitude data needed for filtering, timing selection, thresholding,
and meaningful DSP comparisons.

## Baseline V1 qualification profile

| Item | Baseline |
|---|---|
| Modulation | NRZ OOK / direct intensity modulation |
| Acquisition | Arty XADC channel A0 at 250 kSa/s, 12-bit samples |
| Bring-up rate | 1 kbit/s, fixed threshold, generous oversampling |
| Qualification rate | 10 kbit/s at 25 samples/symbol |
| Stretch rate | 25 kbit/s at 10 samples/symbol, only if measured hardware bandwidth supports it |
| Receiver DSP | DC removal, fixed-point FIR, discrete sample-phase selection, threshold decision |
| Measurement | FPGA-resident PRBS synchronization, BER, lock, saturation, and rate counters |
| Host link | USB-UART packet protocol to a local Python command utility and logger |

Rates are test profiles, not claims about the inexpensive modules. A profile is
accepted only after the measured optical waveform, XADC headroom, sample
integrity, and BER run meet the project-plan criteria.

## Planned bring-up order

1. Inspect the delivered modules, photograph markings, and determine the exact
   pinout before applying power.
2. Run one DAOKI transmitter continuously and use a DAOKI digital receiver to
   establish safe alignment and beam-block detection.
3. Measure the KY-008 `S` input, then prove slow FPGA-controlled OOK through
   that control input without sourcing laser power from the GPIO.
4. Characterize all supplied BPW34-style devices with a 10 kΩ load, then verify
   the sense node stays within 0-3.3 V before connecting it to Arty A0.
5. Capture dark, laser-off, laser-on, transition, and deliberately misaligned
   XADC samples before implementing the receive DSP.
6. Qualify 1 kbit/s first, then 10 kbit/s. Attempt 25 kbit/s only as a measured
   stretch goal.

The detailed implementation order is the
[milestone index](docs/milestones/README.md). It continues from hardware
bring-up through DC removal, FIR filtering, phase/threshold selection, frame
synchronization, BER, UART control, headless logging, and final qualification.

## Safety and electrical rules

- Never look into the laser aperture or beam, point it at a person, or operate
  it at eye level. Use a matte beam stop and enclose the short optical path.
- Treat the inexpensive module as an unverified visible-laser product even if
  the listing claims 5 mW. Do not rely on the listing for a safety class.
- This KY-008 variant takes power/control through `S`; the middle pin is unused.
  Record loaded GPIO voltage and current before accepting direct drive formally.
- A 5 V digital-receiver output must not connect directly to a 3.3 V FPGA pin.
  Verify its high level and use a divider or level shifter when required.
- Only A0-A5 are assumed to accept 0-3.3 V analog signals through the Arty
  board's input network. Direct XADC differential pins remain limited to the
  FPGA's XADC range and are outside the first prototype.
- Share grounds deliberately and check every node with a meter or oscilloscope
  before connecting the Arty.

## Terminal workflow

From a PowerShell terminal in VS Code:

```powershell
# Program the accepted bitstream at the conventional artifact path.
.\scripts\fpga.cmd program

# Program an explicitly selected image.
.\scripts\fpga.cmd program -Bitstream .\path\to\image.bit

# Once scripts/build_bitstream.tcl exists, build and program in one command.
.\scripts\fpga.cmd build-program

# Validate paths and show the Vivado commands without executing them.
.\scripts\fpga.cmd program -Bitstream .\path\to\image.bit -DryRun
```

The wrapper discovers Vivado, records timestamped logs, and delegates hardware
selection and part verification to a batch Tcl script. See
[`scripts/README.md`](scripts/README.md) for arguments and safety behavior.

## Current status

- [x] Scope and evidence policy established.
- [x] Student-scale hardware baseline selected: DAOKI kit, BPW34-style detector,
  and the Arty A7 XADC.
- [x] Fourteen cumulative learning milestones defined with verification gates.
- [x] Terminal-only FPGA programming wrapper prepared.
- [ ] Delivered hardware inspected and electrically characterized.
- [ ] Final wiring and measured rate profiles frozen.

No benchmark result is reported as achieved until its evidence and exit
criteria in the project plan have been satisfied on physical hardware.
