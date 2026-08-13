# Milestone 13 — UART control and telemetry plane

**Time box:** 2 days
**Depends on:** [Milestone 07](07-capture-buffer-and-uart.md) and
[Milestone 12](12-frame-sync-and-ber.md)
**Produces:** A bounded bidirectional protocol, configuration register bank,
coherent status packets, headless host commands, and an evidence logger

## Why this milestone exists

The host tools should operate a stable instrument, not reach into arbitrary FPGA
state. This milestone defines a small control/status plane over the UART packet
format already used for captures. It keeps host disconnection or bad input from
stopping the optical pipeline and makes every benchmark configuration auditable.

## Permanent modules to write

```text
rtl/common/uart_rx.sv
rtl/control/packet_rx.sv
rtl/control/control_registers.sv
rtl/control/telemetry_scheduler.sv
rtl/control/protocol_types.sv       # package/constants
sim/tb/tb_uart_rx.sv
sim/tb/tb_packet_rx.sv
sim/tb/tb_control_registers.sv
sim/tb/tb_control_telemetry_loop.sv
host/optical_dsp_host/commands.py
host/optical_dsp_host/logger.py
host/run_cli.py
host/tests/test_commands.py
host/tests/test_logger.py
```

Reuse the CRC, packet encoder, UART TX, serial transport, and coherent snapshots
from earlier milestones.

## Minimal command set

Keep V1 controls intentionally small:

| Command | Purpose |
|---|---|
| `GET_INFO` | Protocol/build ID, FPGA target, supported profiles |
| `GET_STATUS` | Request coherent status snapshot |
| `SET_RUN` | Start/stop receive measurement without disabling safety logic |
| `SET_TX_MODE` | OFF, ON, TRAINING, or FRAMED |
| `SET_RATE_PROFILE` | 1, 10, or optional 25 kbit/s predefined profile |
| `SET_FILTER` | Enable/bypass and select a preverified coefficient bank |
| `CALIBRATE` | Enter training and start phase/threshold calibration |
| `SET_THRESHOLD_OVERRIDE` | Optional bounded manual diagnostic override |
| `CAPTURE` | Arm/trigger a bounded named sample tap |
| `SNAPSHOT` | Freeze coherent counters/status |
| `RESET_COUNTERS` | Explicitly clear measurement counters and start new run ID |

Do not provide arbitrary memory writes or raw register addresses. Named commands
make the design easier to explain and safer to validate.

## Response and telemetry types

- `ACK`: transaction ID, command, applied value, status.
- `NACK`: transaction ID, command, reason code.
- `INFO`: immutable build/protocol metadata.
- `STATUS`: run ID, snapshot sequence, lock/calibration state, rates, phase,
  threshold, quality, counters, and sticky faults.
- `CAPTURE_META` and `CAPTURE_DATA`: bounded sample evidence.
- `EVENT`: optional low-rate notification of lock loss or fault.

Every mutating command carries a transaction ID. Retrying the same transaction
must return the same acknowledgement without applying the change twice.

## Configuration ownership

`control_registers` owns all host-writable settings. Other modules receive clean
registered outputs. Define when each setting may take effect:

- safety OFF applies immediately;
- rate/profile or filter-bank changes apply only while stopped or at a declared
  frame boundary;
- threshold override applies only after validation and starts a new run;
- counter reset and snapshot are separate pulses; and
- any BER-relevant change increments/creates a run ID so old/new counts cannot
  mix.

## UART RX guidance

At 115200 baud with a 100 MHz clock, sample near the center of each serial bit.
A readable receiver can detect the falling start edge, wait half a bit, verify
the start level, then sample eight data bits and the stop bit at full-bit
intervals.

Record behavior for:

- false start;
- bad stop bit/framing error;
- reset mid-byte;
- back-to-back bytes; and
- byte arrival while the packet parser is busy.

A tiny byte FIFO is acceptable if needed, but first prove whether the packet
parser can consume every byte in real time.

## Packet parser guidance

Use a state machine that searches sync bytes, reads the fixed header, rejects a
length above the maximum, collects a bounded payload, and validates CRC before
emitting a command. No setting changes before CRC and semantic validation pass.

Add a byte-count timeout so a partial packet does not leave the parser stuck.
On any error, return to sync search and increment a reason-specific counter.

## Testbench requirements

### UART RX

1. Send every byte value through an independent serial task and verify output.
2. Add small timing offsets within UART tolerance.
3. Exercise false starts, invalid stop bits, and back-to-back frames.
4. Confirm exact error pulses/counters and idle recovery.

### Parser/control

1. Valid command for every type: verify exact applied setting and ACK payload.
2. Bad sync, version, length, command, parameter range, CRC, and timeout: require
   rejection with no configuration mutation.
3. Duplicate transaction: return consistent ACK without repeating the side
   effect.
4. Attempt unsafe mode/rate changes while running and verify policy.
5. Snapshot and reset while live counters increment.
6. Random byte noise followed by a valid packet; parser must resynchronize.
7. End-to-end simulated UART command in and status UART packet out, decoded by
   the permanent Python host library.

## Hardware verification

Build a headless host command utility and evidence logger. They should:

- query info/status;
- set TX mode and rate;
- trigger calibration and wait for completion;
- start/stop a BER run;
- request a capture; and
- save every command/ACK/status packet with timestamps;
- write a run manifest with Git commit, bitstream/build ID, hardware IDs,
  settings, and start/stop times; and
- save status counters and bounded captures in machine-readable files.

Unplug/replug or close/reopen the serial host while the FPGA runs. The optical
pipeline must continue; reconnection should recover through `GET_INFO` and
`GET_STATUS`, not a board reset.

## Completion evidence

- Frozen protocol table with field offsets, byte order, CRC, packet IDs, command
  ranges, and reason codes.
- Passing malformed-packet and duplicate-transaction tests.
- A hardware command/status transcript decoded by the Python library.
- Ten-minute telemetry run with no malformed packets or unexplained sequence
  gaps.
- One complete logged run directory with a manifest, packet/command log,
  counter data, captures, and final result summary.

## Done when

- [ ] Invalid bytes cannot mutate FPGA configuration.
- [ ] All settings have one owner and a safe application boundary.
- [ ] Host retries are idempotent.
- [ ] Snapshots are coherent and identify their run/build/configuration.
- [ ] FPGA measurement continues when the host disconnects.
- [ ] The headless logger preserves raw counters and enough identity metadata
  to reproduce a qualification run.

## Scope guard

Do not build Ethernet, TCP, a soft CPU, a general register bus, remote firmware
updates, or a graphical frontend. UART plus the headless tools keep the
learning path focused on the signal-processing system.

## What this unlocks

Milestone 14 can run integration and qualification against a tested host
library, stable protocol, and reproducible evidence logger.
