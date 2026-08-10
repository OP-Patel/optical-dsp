# Milestone 12 — Frame synchronization and BER engine

**Time box:** 2 days
**Depends on:** [Milestone 11](11-phase-and-threshold.md) and the protocol frozen
in [Milestone 04](04-training-pattern-and-framer.md)
**Produces:** Hardware frame lock, payload alignment, PRBS comparison, and
coherent error/statistics counters

## Why this milestone exists

A believable optical DSP demo needs more than readable bits. The receiver must
find frames, distinguish synchronization failures from payload errors, align
the expected PRBS, and count enough evidence to state a BER. Keeping these
responsibilities explicit prevents a low BER number from hiding repeated lock
losses.

## Receive sequence

The input is `bit_valid` plus `bit_in`, one event per selected symbol.

A readable V1 receiver can:

1. Search for the 32-bit alternating preamble.
2. Require the frozen 16-bit sync word immediately afterward.
3. Shift in the 16-bit sequence field, MSB first.
4. Pulse `payload_start`, reload the PRBS checker seed, and compare exactly 1024
   payload bits.
5. Return to preamble search for the next frame.

Use a tolerance for the preamble rather than requiring perfect training under a
degraded condition, but freeze the tolerance before BER comparison. Sync-word
matching should be exact initially; any later Hamming-distance tolerance must be
explicit and separately counted.

## Permanent modules to write

```text
rtl/sync/preamble_detector.sv
rtl/sync/frame_sync.sv
rtl/bert/ber_counters.sv
rtl/bert/coherent_snapshot.sv
sim/tb/tb_preamble_detector.sv
sim/tb/tb_frame_sync.sv
sim/tb/tb_ber_counters.sv
```

Reuse `prbs15_check.sv` from Milestone 03 rather than writing a second PRBS
algorithm.

## Counter set

Use wide counters in the integrated design, preferably 64 bits:

- valid decided bits;
- compared payload bits;
- payload bit errors;
- detected preambles;
- good sync words;
- completed frames;
- sequence discontinuities;
- framing failures;
- lock acquisitions;
- lock losses;
- calibration faults;
- DSP saturation events; and
- sample discontinuities/capture overruns from earlier blocks.

Counters should saturate or wrap according to one documented policy. Saturation
is easier to explain for fault counters; natural wrap plus snapshot history can
be acceptable for high-rate totals. Mixed policy is allowed only if every field
is defined.

## Lock policy

Separate frame parsing state from a reported `link_locked` status. A simple
hysteresis policy is:

- acquire reported lock after two consecutive correctly structured frames;
- retain lock through payload bit errors;
- lose lock after two consecutive missing/invalid frame boundaries; and
- count acquisition and loss events separately.

The exact policy may change, but it must be deterministic and tested. Payload
errors alone must not silently reset the BER denominator.

## Coherent snapshot

The UART cannot read a 64-bit counter atomically while it changes. On a snapshot
request, copy every live counter and status field into a shadow bank on one
clock edge, assign a snapshot sequence number, and let telemetry read only the
shadow values. Counter reset is a separate explicit operation.

## SystemVerilog guidance

- Shift registers make preamble/sync search easy, but confirm bit order with a
  known pattern.
- A Hamming-distance preamble score can count mismatched alternating positions.
  Parameterize the accepted error count only after the exact version works.
- Advance state, field index, PRBS checker, and counters only on `bit_valid`.
- Use one-cycle events such as `frame_start`, `payload_start`, and
  `frame_complete` to keep modules loosely coupled.
- Incrementing a 64-bit counter at 10 kbit/s is easy at 100 MHz; optimization is
  unnecessary.
- When several events affect one counter on the same cycle, define precedence
  and combine increments rather than assigning the register twice.
- Keep BER as raw numerator/denominator counters. Do not synthesize floating-
  point division; the host calculates and formats the ratio.

## Testbench requirements

Create a bit-level channel task that takes a correct frame and can flip, insert,
delete, or suppress selected bits.

1. Clean stream: acquire lock, compare at least one million payload bits, and
   report zero errors with correct frame/bit totals.
2. Exact error injection: flip known payload bit positions and require exact
   error count without a framing loss.
3. Preamble errors inside and outside the allowed tolerance.
4. Corrupted sync word: frame must not enter payload comparison.
5. Bit insertion and deletion: demonstrate framing loss and deterministic
   reacquisition; do not expect BER alignment to survive silently.
6. Sequence skip/repeat: increment the sequence-discontinuity counter.
7. Reset in every receive state.
8. Stop `bit_valid` temporarily and confirm state/counters hold.
9. Lock hysteresis: test every acquisition/loss boundary and ensure no false
   lock over randomized noise bits.
10. Snapshot while counters change; all shadow fields must represent the same
    snapshot event.
11. Counter near-overflow test with reduced parameterized widths.

## Hardware verification

Run in increasing difficulty:

1. Internal digital loopback from framer bit to synchronizer.
2. DAOKI digital diagnostic loopback at a supported slow rate, clearly labeled
   diagnostic only.
3. BPW34/XADC/DSP path at 1 kbit/s.
4. BPW34/XADC/DSP path at 10 kbit/s under nominal conditions.
5. Block/unblock and frozen degraded-condition tests.

For zero observed errors in `N` compared bits, report the one-sided 95% upper
bound of approximately `3/N`; never write only “BER = 0.”

## Completion evidence

- State diagram for search/header/payload behavior.
- Counter and lock-policy specification.
- Passing million-bit clean run plus exact corruption tests.
- Hardware snapshots showing compared bits, errors, frames, and lock events.
- Reacquisition trace after a controlled interruption.

## Done when

- [ ] Frame and PRBS alignment are deterministic.
- [ ] Payload errors, framing failures, and lock losses are separate quantities.
- [ ] Exact injected faults produce exact counters.
- [ ] Snapshot values are coherent and independently resettable.
- [ ] Physical BPW34 path acquires and retains lock at 10 kbit/s nominally.

## What this unlocks

The measurement engine is complete. Milestone 13 can expose stable controls and
snapshots to the host without changing the signal path.
