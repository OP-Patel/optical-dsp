# Milestone 06 — Single-channel XADC acquisition

**Time box:** 1-2 days
**Depends on:** [Milestone 02](02-reset-and-clock-enables.md) and verified Arty
A0-A5 documentation from Milestone 01
**Produces:** A permanent, single-channel 12-bit sample stream from Arty A0

## Why this milestone exists

The BPW34 receiver is only useful if analog voltage becomes a trustworthy sample
stream. Bring up the XADC with known electrical inputs before attaching the
photodiode. This separates converter configuration and code mapping from optical
alignment, ambient light, and front-end behavior.

## Learning goals

- Understand the Arty A0-A5 external scaling network versus the XADC's internal
  0-1 V range.
- Understand the hardened XADC primitive, conversion sequencing, end-of-
  conversion event, and DRP readback.
- Produce a `sample_valid` pulse exactly once per new conversion.
- Convert raw codes to expected external voltage for documentation/host display.
- Distinguish ADC resolution, sample rate, accuracy, and noise.

## Vendor primitive boundary

Instantiating AMD's XADC primitive is allowed because it represents hardened
silicon. You still write and explain:

- primitive configuration attributes or a thin wrapper around a generated
  instance;
- the selected auxiliary analog channel;
- DRP address, enable, ready, and data handling;
- sample-valid generation and sample index;
- reset/startup behavior; and
- the top-level analog pin constraints.

Avoid a large Vivado block design. The learning target is a readable wrapper
whose behavior is covered by your own testbench model.

## Permanent modules to write

```text
rtl/acquisition/xadc_single_channel.sv
rtl/acquisition/sample_index.sv       # optional separate counter
sim/models/xadc_model.sv
sim/tb/tb_xadc_single_channel.sv
rtl/top/xadc_bringup_top.sv
```

Suggested output contract:

| Port | Meaning |
|---|---|
| `sample_valid` | One system-clock pulse per newly accepted conversion |
| `sample_u12` | Right-aligned unsigned 12-bit conversion result |
| `sample_index` | Monotonic counter incremented with `sample_valid` |
| `xadc_busy` | Startup/conversion diagnostic status |
| `xadc_fault` | Sticky impossible-state/timeout indication |

The XADC's DRP data bus may place the 12-bit result in the upper bits. Do not
assume alignment; confirm it from UG480 and test the extraction.

## Configuration decisions to document

- Single-channel or sequencer mode: use the simplest one-channel setting.
- Selected A0-A5 channel and matching `vaux` mapping.
- XADC clock division and actual conversion rate.
- Continuous conversion versus explicitly triggered sampling.
- Averaging disabled initially so individual samples are observable.
- Unipolar input mode and external voltage conversion equation.
- Alarm outputs: either intentionally unused or surfaced as diagnostics.

The project target is 250 kSa/s. If the primitive naturally produces a nearby
rate, either accept every conversion and record the measured rate or decimate
with an explicit, tested rule. Never relabel a rate without measuring it.

## SystemVerilog guidance

- Treat `DRDY`/end-of-conversion events as one-cycle events unless the guide
  states otherwise; capture data on the documented event.
- Keep a timeout counter around a DRP transaction so a configuration mistake
  becomes a visible fault rather than a silent hang.
- Right-align the sample once in the wrapper. Downstream logic should not know
  the primitive's bus packing.
- Use a wide sample index, preferably 64 bits in the integrated design. A smaller
  parameter is acceptable in unit simulation to exercise rollover policy.
- Do not use real-number arithmetic in synthesizable voltage conversion. Raw
  codes stay raw in RTL; volts are calculated in documentation/host software.

## Testbench model

Do not attempt to simulate analog physics. Write a small behavioral XADC model
that responds to the wrapper's handshake with chosen 12-bit codes and realistic
latency. This tests your controller, alignment, valid pulse, timeout, and index.

Required tests:

1. Return codes `0x000`, `0x001`, `0x800`, and `0xFFF`; verify exact extraction.
2. Vary conversion/DRP latency and ensure one valid pulse per result.
3. Confirm sample indices are consecutive with no duplicate event.
4. Stall the model beyond the timeout and require a sticky fault.
5. Reset during startup and during an outstanding read.
6. Run enough events to verify the configured sample-enable relationship.
7. If averaging or decimation is enabled later, test its exact cadence separately.

## Electrical hardware checks

Before attaching BPW34:

1. Tie A0 to ground through an appropriate resistor and capture the raw code.
2. Apply at least two known safe DC voltages between 0 and 3.3 V using a divider
   measured by a multimeter.
3. Compare mean code with the Arty scaling equation; record offset and spread.
4. Never exceed 3.3 V on A0 and never apply 3.3 V directly to an unscaled
   differential XADC input.
5. Measure the actual valid-pulse rate with a counter over a known time window.

## Completion evidence

- Wrapper configuration table with source references.
- Passing behavioral-model testbench and timeout test.
- CSV or small table of applied voltage, expected code, measured mean, minimum,
  maximum, and standard deviation.
- Measured samples per second and explanation of any target difference.
- Constraint excerpt identifying the exact analog channel.

## Done when

- [ ] Every conversion produces one right-aligned 12-bit sample and one index.
- [ ] Known electrical inputs map monotonically to plausible codes.
- [ ] No sample event is duplicated or silently dropped in the long unit test.
- [ ] Reset and timeout behavior are observable and documented.
- [ ] The BPW34 has not yet been used to hide an acquisition problem.

## What this unlocks

Milestone 07 can retain bounded sample windows and send them to the PC, creating
the evidence path needed to characterize the BPW34 receiver in Milestone 08.
