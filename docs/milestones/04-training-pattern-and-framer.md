# Milestone 04 — Optical training pattern and framer

**Time box:** 1-2 days
**Depends on:** [Milestone 03](03-prbs15-source-and-checker.md)
**Produces:** The permanent transmitter bitstream generator used for alignment,
calibration, synchronization, and BER payloads

## Why this milestone exists

The transmitter needs more than raw PRBS bits. A continuous alternating mode
lets you observe clean optical transitions and calibrate sample phase. A framed
mode gives the receiver a known preamble, sync marker, frame number, and PRBS
payload boundary. These modes belong in one permanent module so hardware tests
do not require temporary transmitters.

## Frozen V1 frame

```text
32-bit alternating preamble | 16-bit sync | 16-bit frame sequence |
1024-bit PRBS-15 payload
```

Baseline details:

- Logical `1` commands laser on; logical `0` commands laser off.
- Fixed fields transmit most-significant bit first.
- The preamble is 32 alternating bits beginning with `1`.
- Freeze one 16-bit sync word in `docs/protocol.md`; choose a value with useful
  transitions and no long run of identical bits.
- The sequence increments once per completed frame and wraps naturally.
- PRBS state reloads to the Milestone 03 seed at every payload start.
- There is no payload CRC in V1 because the PRBS checker measures raw errors.

## Permanent modules to write

```text
rtl/tx/optical_framer.sv
rtl/tx/tx_mode_control.sv       # optional if mode handling would clutter framer
sim/tb/tb_optical_framer.sv
```

Suggested transmit modes:

| Mode | Output | Permanent use |
|---|---|---|
| `OFF` | Constant `0` | Safe idle and dark measurement |
| `ON` | Constant `1` | Alignment and maximum-light measurement |
| `TRAINING` | Continuous `1010...` | Bandwidth, phase, and threshold calibration |
| `FRAMED` | Repeating frozen frame | Synchronization and BER |

## Suggested interface

| Port | Meaning |
|---|---|
| `clk`, `rst` | System timing |
| `symbol_ce` | Advance exactly one transmitted symbol |
| `mode` | Selected mode; apply changes at a defined safe boundary |
| `prbs_bit` | Current output from the reusable PRBS generator |
| `prbs_load_seed`, `prbs_advance` | Explicit control back to the PRBS generator |
| `tx_bit` | Current logical optical bit |
| `frame_start`, `payload_start` | One-cycle debug events |
| `frame_sequence` | Current frame number for debug/status |

You may instantiate `prbs15_gen` inside the framer instead of exposing the PRBS
ports, but state the ownership clearly. One module must be responsible for seed
load and advance.

## State-machine guidance

Use named states corresponding to frame fields rather than one opaque bit
counter. A simple structure is:

```text
IDLE/TRAINING -> PREAMBLE -> SYNC -> SEQUENCE -> PAYLOAD -> PREAMBLE
```

Each state owns:

- the source of `tx_bit`;
- the field bit index;
- the condition for moving to the next state; and
- any one-cycle event such as `payload_start`.

Advance field indices only on `symbol_ce`. The state machine may execute at
100 MHz, but the optical bit changes only on a symbol event.

## SystemVerilog guidance

- Use an enumerated type for states so waveforms show meaningful names.
- Separate next-state/output combinational logic from registered state, or use
  one carefully structured sequential process. Be able to explain your choice.
- Index fixed words predictably. An expression based on `WIDTH-1-index` makes
  MSB-first order explicit, but test the first and last bit.
- Avoid unsized shifts and mixed signedness.
- Define what happens if mode changes in the middle of a frame. The simplest
  explainable policy is to apply a pending mode after the current frame, except
  that `OFF` may be allowed to force an immediate safe idle.

## Testbench requirements

1. For each mode, compare at least 100 emitted symbols with an independent
   expected sequence.
2. In framed mode, verify every boundary and exact total frame length:
   `32 + 16 + 16 + 1024 = 1088` symbols.
3. Check preamble start bit, alternating polarity, sync bit order, and sequence
   bit order.
4. Confirm PRBS seed loads exactly once at payload start and advances exactly
   1024 times.
5. Capture two consecutive frames and prove sequence increment plus identical
   seeded payloads.
6. Pause `symbol_ce` at every state; output and field position must hold.
7. Change modes at awkward times and prove the documented transition policy.
8. Reset in each state and require safe laser-off output immediately according
   to your reset policy.

The testbench should build an expected frame from constants and the already
verified PRBS golden vector. Do not simply inspect a waveform.

## Completion evidence

- A protocol table with exact bit counts, values, bit order, and reset policy.
- Passing self-check for at least two complete frames.
- State-transition waveform labeled with `symbol_ce`, `tx_bit`, and field events.
- Synthesis result showing no generated clock and no inferred latch.

## Done when

- [ ] All four modes are deterministic and safe on reset.
- [ ] The frame is exactly 1088 symbols under stalls in `symbol_ce`.
- [ ] PRBS control aligns exactly with payload boundaries.
- [ ] Mode changes follow a documented, tested rule.
- [ ] The module is independent of the laser pin and physical hardware.

## What this unlocks

Milestone 05 can connect a stable logical transmit stream to the permanent
transistor-controlled laser output and use the training modes for safe bring-up.
