# Milestone 05 — Laser transmitter and DAOKI digital bring-up

**Time box:** 1-2 days
**Depends on:** [Milestone 04](04-training-pattern-and-framer.md) and completion
of the hardware checklist in the main project plan
**Produces:** The permanent FPGA-controlled optical transmitter and a retained
digital diagnostic path

## Why this milestone exists

This is the first physical optical milestone, but it deliberately avoids analog
DSP. The DAOKI digital receiver answers a narrow question: does the safely
switched laser reach the receiver and follow slow commands? Solving power,
polarity, alignment, control-input loading, and level translation here prevents those problems from
being misdiagnosed as XADC or DSP bugs later.

## Safety gate

Do not energize the module until all are true:

- the received module pinout has been identified from markings and measurement;
- the delivered KY-008 pinout is confirmed as `S` positive/control, `-` ground,
  and middle pin unused;
- the KY-008 loaded `S` voltage and high-level GPIO current have been measured
  and accepted for direct drive;
- Arty and external supply grounds are intentionally common;
- the optical path ends in a matte stop and is not at eye level; and
- no person can enter the beam path during testing.

Treat the marketplace “5 mW” value and safety class as unverified.

## Permanent hardware arrangement

Validate the provisional wiring from the main plan. For this delivered variant,
connect `S` to guarded JA4 and `-` to JA5 ground; leave the middle pin
disconnected. Functional operation alone is not the electrical acceptance
criterion: record the loaded JA4/S high voltage and GPIO current and compare
them with the selected output-drive limit.

The FPGA output must default low before and during configuration. Record the
laser module's measured off current, on current, and supply voltage.

## Permanent RTL to write

```text
rtl/tx/laser_output_guard.sv
rtl/top/optical_tx_bringup_top.sv
sim/tb/tb_laser_output_guard.sv
```

`laser_output_guard` is intentionally small but permanent. It combines the
framer bit with explicit safety conditions.

Suggested inputs:

| Signal | Purpose |
|---|---|
| `tx_bit` | Requested optical bit from the framer |
| `tx_enable` | Software/hardware permission to emit |
| `fault` | Live indication that `tx_bit` requested ON while disabled |
| `rst` | Forces safe state |
| `laser_drive` | Only signal routed to the KY-008 `S` input |

Define a truth table before coding. Reset or disable must always produce
laser-off regardless of `tx_bit`. In the baseline combinational guard, `fault`
is a live diagnostic output, not stored sticky state. A sticky fault would
require a flip-flop plus a defined clear/reset policy.

## DAOKI receiver diagnostic

The receiver listing claims a high output under illumination and low otherwise,
but verify polarity and voltage yourself. Observe it without the Arty first. If
powered at 5 V and its high level exceeds the FPGA input limit, use the planned
divider or a level shifter and measure the translated value before connection.

Route the translated signal to one FPGA input and expose it on an LED or status
bit. This diagnostic input can remain in the final design as an alignment aid,
but it is never used to claim analog DSP performance.

## SystemVerilog guidance

- Keep the baseline guard combinational: `laser_drive` is true only when reset
  is inactive, transmission is enabled, and `tx_bit` is true. The module does
  not need a clock.
- Do not invert the laser polarity in multiple modules. `tx_bit=1` means logical
  on; perform any physical inversion in exactly one documented wrapper.
- Synchronize the DAOKI receiver input before using it in sequential logic
  because it is asynchronous to the FPGA clock.
- A two-flop synchronizer prevents metastability propagation but does not
  debounce or preserve very short pulses. That is acceptable for this slow
  diagnostic path.
- Keep the diagnostic receiver out of the final BER datapath.

## Testbench requirements

### Output guard

Exhaustively test every combination of reset, enable, and requested bit. Assert
that no forbidden combination produces `laser_drive=1`, and that `fault` is
true only for an ON request while reset is inactive and transmission is
disabled. Change inputs between clock events to prove the declared
combinational policy does not depend on a clock.

### Input synchronizer

If you create a reusable synchronizer, test delayed propagation and verify that
the synchronized signal changes only on clock edges. Simulation cannot prove
metastability safety, so also explain the structural reason for two stages.

## Physical test sequence

1. Power the laser in `OFF` mode and confirm no light/current beyond leakage.
2. Command `ON` only long enough to align it with the matte stop.
3. Place the DAOKI receiver in the beam and record output voltages for blocked
   and illuminated conditions.
4. Connect the level-translated output and verify the FPGA diagnostic LED.
5. Run `TRAINING` first at a human-visible slow rate, then 1 kbit/s. The digital
   receiver may fail at higher rates; that is a recorded module limitation, not
   a project failure.
6. Run framed mode at 1 kbit/s and confirm the optical output switches without
   resetting or heating unexpectedly.

## Completion evidence

- Annotated wiring photo and measured supply/current table.
- DAOKI receiver raw and translated high/low voltages.
- Passing safety-guard testbench.
- Logic-analyzer/oscilloscope trace if available, otherwise a documented slow
  LED test plus measured DC behavior.
- A clear statement of the highest observed DAOKI digital-receiver rate, without
  treating it as the BPW34 path's limit.

## Done when

- [ ] Reset or disable forces the KY-008 control command off.
- [ ] Direct GPIO drive through `S` has measured-safe loaded voltage and current;
  the middle pin remains disconnected.
- [ ] The receiver signal presented to the FPGA is within 3.3 V limits.
- [ ] OFF, ON, TRAINING, and FRAMED modes work at the safe bring-up rate.
- [ ] Wiring, polarity, currents, voltages, and limitations are recorded.

## What this unlocks

The final optical transmitter is now stable. Milestone 06 can develop XADC
acquisition electrically, without changing the transmitter architecture.
