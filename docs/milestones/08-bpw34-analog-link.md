# Milestone 08 — BPW34 analog-link characterization

**Time box:** 1-2 days
**Depends on:** [Milestone 05](05-laser-and-daoki-bringup.md),
[Milestone 06](06-xadc-acquisition.md), and
[Milestone 07](07-capture-buffer-and-uart.md)
**Produces:** The final V1 detector, load resistance, geometry, signal range,
and verified 1/10 kbit/s analog path

## Why this milestone exists

This milestone makes the hardware choice once, using measurements. You are not
building several receiver prototypes. You screen the purchased BPW34-style
parts, choose a load resistor from a small controlled sweep, and freeze the V1
front end. Later DSP work uses these captured characteristics and does not
redesign the analog path unless the 10 kbit/s baseline is impossible.

## Starting circuit

Use the provisional reverse-biased circuit from the main project plan:

```text
3.3 V -> photodiode cathode
photodiode anode -> sense node -> Arty A0
sense node -> load resistor -> GND
```

Start at 10 kΩ. The expected sense voltage rises with light and is bounded by
the 3.3 V bias, but verify polarity and voltage before connecting A0. If the
device behaves oppositely, disconnect and identify its actual pinout; do not
“fix” polarity in RTL.

## Questions this milestone must answer

1. Which of the five photodiodes has the most repeatable useful response?
2. What are dark, ambient, laser-off, laser-on, and blocked-path code ranges?
3. Does 10 kΩ provide both useful amplitude separation and sufficiently fast
   edges at 10 kbit/s?
4. Does the sense node remain within 0-3.3 V under maximum illumination?
5. How sensitive is the result to distance, alignment, and room lighting?
6. What fixed geometry and impairment method will later benchmarks use?

## Controlled, limited sweep

This is not a sequence of new prototypes. Use the same circuit and socketed
resistor, then freeze one result.

Suggested resistor set:

- 4.7 kΩ: more bandwidth/headroom, less voltage sensitivity;
- 10 kΩ: baseline;
- 47 kΩ: more voltage sensitivity, potentially slower edges.

Skip values you do not own. Do not add an op-amp in this milestone unless none
of the available values can separate on/off at 1 kbit/s. If that occurs, stop
and document the measured blocker before expanding scope.

## Reuse existing RTL

No new DSP module is needed. Build a milestone top from permanent blocks:

```text
framer -> output guard -> laser
XADC -> sample capture -> packet TX -> UART
```

Add only configuration wiring or status required to select OFF, ON, TRAINING,
and FRAMED modes. Do not write a temporary filter or threshold detector.

## Measurement procedure

For each photodiode ID at 10 kΩ:

1. Capture dark/covered samples.
2. Capture room-ambient samples with laser off.
3. Capture aligned laser-on DC samples.
4. Capture continuous training pattern at 1 kbit/s.
5. Record mean, standard deviation, minimum, maximum, and on/off separation.

Choose the best two devices, then sweep the available resistor values at fixed
geometry:

1. OFF and ON DC captures.
2. Training captures at 1 kbit/s and 10 kbit/s.
3. Optional 25 kbit/s observation only after 10 kbit/s succeeds.
4. Block/unblock and small repeatable misalignment captures.

Use the same number of samples, distance, supply voltage, ambient condition, and
laser module ID for comparisons.

## Analysis to perform yourself

For each capture calculate:

```text
separation = mean_on - mean_off
pooled_noise ≈ sqrt(std_on^2 + std_off^2)
simple_quality = separation / pooled_noise
```

Also estimate rise/fall time in samples and compare it with the samples per
symbol. This quality number is not a calibrated optical SNR; label it as a
relative engineering metric.

Plot:

- raw training samples versus sample index;
- histograms for off and on levels;
- mean/separation versus resistor value; and
- one overlaid edge at 1 and 10 kbit/s.

## Verification requirements

- Every capture packet passes CRC and has consecutive sample indices.
- No capture hits code 0 or 4095 unintentionally; if it does, explain clipping.
- Repeat the chosen configuration three times after realigning from scratch.
- The selected setup must show distinguishable levels at 10 kbit/s with enough
  transition margin for later phase selection.
- Record failures honestly; do not select only the cleanest capture.

## Freeze record

Create `docs/hardware/optical-afe-selection.md` containing:

- chosen DAOKI transmitter ID and photodiode ID;
- verified photodiode orientation and load resistance;
- exact wiring, distance, mounting, beam stop, and ambient-light policy;
- measured code ranges and transition times;
- nominal and degraded alignment settings;
- evidence paths and capture hashes; and
- the trigger that would justify a future TIA.

## Done when

- [ ] All available detectors were screened consistently.
- [ ] One detector/load/geometry is frozen for V1.
- [ ] 10 kbit/s training transitions are captured without unsafe voltage or
  unexplained clipping.
- [ ] Nominal and degraded conditions are repeatable three times.
- [ ] The analog selection record is complete enough to rebuild the circuit.

## Scope guard

Do not optimize for 25 kbit/s at the expense of finishing 10 kbit/s. Do not add
multiple analog boards, automatic gain control, or a custom PCB. Those are V2
ideas after the complete baseline works.

## What this unlocks

Milestones 09-11 can design fixed-point receive processing against actual signal
ranges rather than assumed ones.
