# Milestone 03 — PRBS-15 source and checker

**Time box:** 1-2 days
**Depends on:** [Milestone 02](02-reset-and-clock-enables.md)
**Produces:** A deterministic PRBS-15 source and an independently verified
checker used by the framer, loopback tests, and final BER engine

## Why this milestone exists

A pseudorandom binary sequence gives the optical link varied transitions while
remaining exactly reproducible. It also enables hardware BER measurement: the
receiver generates the same expected sequence and counts differences. Building
the source and checker as small independent components makes later debugging
far easier than embedding LFSR logic inside a framer or BER state machine.

## Frozen convention

Use one convention everywhere and record it in `docs/protocol.md`:

| Item | Baseline |
|---|---|
| Polynomial | `x^15 + x^14 + 1` |
| State width | 15 bits |
| Seed | `15'h0001` unless your verified convention requires a different non-zero seed |
| Zero state | Illegal; detect/reseed defensively |
| Advance | Once per asserted `advance` |
| Output | One named state bit, explicitly documented |
| Payload policy | Reset to the frozen seed at the start of every optical payload |

The polynomial alone is not a full implementation specification. Your design
note must state shift direction, output bit, feedback equation, whether output
is observed before or after the shift, and the first 32 generated bits.

## Permanent modules to write

```text
rtl/common/prbs15_gen.sv
rtl/common/prbs15_check.sv
sim/tb/tb_prbs15_gen.sv
sim/tb/tb_prbs15_check.sv
docs/protocol.md
```

### Generator contract

| Port | Meaning |
|---|---|
| `clk`, `rst` | System clock and synchronous reset |
| `load_seed` | Load the defined seed without advancing |
| `advance` | Advance one PRBS bit on this cycle |
| `bit_out` | Current output bit under the frozen convention |
| `state` | Optional debug visibility for simulation/status |

### Checker contract

Keep the checker simple. It may contain a second PRBS generator or instantiate
the generator module.

| Port | Meaning |
|---|---|
| `load_seed` | Align expected sequence at payload start |
| `bit_valid` | Received bit is valid and should be compared |
| `bit_in` | Received decision |
| `error_pulse` | One cycle high when valid input differs from expected |
| `compared_count`, `error_count` | Optional small unit-test counters; final wide counters can wrap the checker later |

## Design hints

- Draw the 15 flip-flops and feedback taps before coding.
- Update state only on `advance`; holding the state is part of the contract.
- Decide priority when `rst`, `load_seed`, and `advance` coincide. A readable
  order is reset, seed load, then advance.
- The all-zero state never escapes. A defensive reseed makes hardware behavior
  explainable after corruption.
- Do not use random-number system functions in synthesizable code. The sequence
  is deterministic logic, not simulation randomness.
- Keep bit comparison and counter updates on the same valid event so there is no
  ambiguity about which expected bit was used.

## Independent reference

Before writing RTL, create a 32- or 64-bit golden sequence manually with a short
calculation table or a tiny disposable calculation in your engineering notes.
Do not generate the testbench's expected bit by copying the RTL feedback
expression into another block; that can repeat the same mistake.

For additional confidence, prove the LFSR period is `2^15-1 = 32767` advances
before the seed repeats and that zero never appears.

## Testbench requirements

### Generator

1. After reset/seed, compare at least the first 64 bits with the frozen golden
   vector.
2. Leave `advance=0` for irregular intervals and prove state/output hold.
3. Advance exactly 32767 times; the seed must recur only at the end.
4. Confirm the all-zero state is never visited.
5. Exercise simultaneous control signals and verify your documented priority.

### Checker

1. Connect a generator directly to the checker; compare at least 100,000 bits
   with zero errors.
2. Flip known bit numbers, such as 0, 17, and 999; require exactly three errors.
3. Deassert `bit_valid` around corrupted inputs; ignored bits must not advance
   the expected sequence or counters.
4. Reload the seed mid-run and confirm deterministic restart.
5. Check counter reset and, if implemented, overflow/saturation policy.

## Completion evidence

- Golden first-bit vector and stated LFSR convention in `docs/protocol.md`.
- Passing period test and checker error-injection transcript.
- Waveform screenshot showing seed load, held state, advance, and error pulse.
- One paragraph explaining why the maximum-length period matters for BER tests.

## Done when

- [x] The sequence convention is unambiguous.
- [x] The generator passes its golden-vector and full-period tests.
- [x] The checker reports exact injected errors and compared-bit counts.
- [x] Both blocks advance only on explicit valid/enable events.
- [x] The zero-state behavior is intentional and tested.

## Common traps

- Choosing taps from a polynomial table without matching its shift convention.
- Comparing the received bit with the expected state after it has already
  advanced.
- Advancing the checker when no received bit is valid.
- Using two subtly different PRBS implementations in TX and RX.

## What this unlocks

Milestone 04 can build a readable optical frame around a trusted payload source,
and Milestone 12 can reuse the same checker for physical BER measurement.
