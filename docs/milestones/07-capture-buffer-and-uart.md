# Milestone 07 — Capture buffer and UART evidence path

**Time box:** 2 days
**Depends on:** [Milestone 06](06-xadc-acquisition.md)
**Produces:** A permanent bounded sample-capture tap, UART transmitter, packet
encoder, and reusable Python packet decoder

## Why this milestone exists

You need to see real XADC samples before designing filters. Continuously sending
250 kSa/s over a basic UART is neither necessary nor reliable. Instead, capture
a bounded block at full sample rate, freeze it, and transmit it afterward. The
capture tap remains in the final design for diagnostics and offline plots.

## Permanent components

```text
rtl/common/uart_tx.sv
rtl/common/crc16_ccitt.sv
rtl/control/packet_tx.sv
rtl/acquisition/sample_capture.sv
rtl/control/capture_streamer.sv
sim/tb/tb_uart_tx.sv
sim/tb/tb_crc16_ccitt.sv
sim/tb/tb_sample_capture.sv
sim/tb/tb_packet_tx.sv
host/optical_dsp_host/protocol.py
host/optical_dsp_host/serial_transport.py
host/tests/test_protocol.py
```

The Python files begin the final host library; do not write a one-off decoder
that will be discarded before the command and evidence tools are complete.

## UART TX contract

Use 115200 baud, 8 data bits, no parity, one stop bit. With a 100 MHz clock, an
integer divider of 868 clocks per bit has very small baud error; calculate and
record the exact actual baud. Use the Milestone 02 enable style rather than a
generated UART clock.

Suggested byte interface:

| Signal | Meaning |
|---|---|
| `data_valid` | Producer presents a byte |
| `data_byte` | Byte to send |
| `data_ready` | UART can accept a byte this cycle |
| `tx` | Idle-high serial output |
| `busy` | A frame is in progress |

Once accepted, the UART owns a copy of the byte. The producer must not overwrite
it while busy.

## Packet format

Freeze a bounded transport that Milestone 13 can extend bidirectionally:

```text
sync[2] | version[1] | type[1] | payload_length[2] | sequence[2] |
payload[0..MAX] | CRC16[2]
```

Decide and document:

- exact sync bytes;
- byte order for 16-bit fields;
- CRC-16/CCITT initial value, polynomial, input order, and covered bytes;
- maximum payload length;
- packet types for status and sample capture; and
- how the decoder resynchronizes after noise or a partial packet.

A capture packet should include sample start index, sample count, sample format,
and packed samples. Keep each 12-bit sample in a 16-bit field initially; saving
bandwidth is less important than readability.

## Capture-buffer contract

Use a fixed or parameterized depth such as 1024 samples.

| Input/control | Behavior |
|---|---|
| `arm` | Prepare an empty capture |
| `trigger` | Begin accepting the next valid sample |
| `sample_valid`, `sample_u12`, `sample_index` | Acquisition stream |
| `capture_done` | Buffer is frozen and complete |
| read address/data | Separate post-capture read port for the streamer |

The capture must never backpressure XADC. If triggered while busy, reject the
request and set a visible status flag rather than corrupting the current buffer.

For V1, inferred registers are acceptable at 1024 samples, but learn the coding
style that allows Vivado to infer block RAM. A single writer and a separate
read-after-capture phase keep ownership clear.

## SystemVerilog guidance

- UART is a state machine: idle, start bit, eight data bits, stop bit. Register
  the accepted byte and shift from that register.
- Confirm whether bit 0 or bit 7 is transmitted first; standard UART sends LSB
  first.
- `data_valid/data_ready` is a one-cycle transfer when both are high. Document
  whether valid may stay asserted until accepted.
- For CRC, update once per accepted byte. Load the initial value at packet start
  and append the final value only after the covered bytes.
- The packet encoder should not know where payload bytes originate. Give it a
  small request/byte-stream interface so status and capture producers can reuse
  it.
- Do not read a memory entry on the same cycle you change its synchronous read
  address and assume zero latency; model the chosen RAM behavior.

## Testbench requirements

### UART TX

1. Decode the simulated `tx` line independently and verify several bytes,
   including `00`, `FF`, `55`, and `A6`.
2. Check start, data, and stop duration in system-clock cycles.
3. Present bytes back-to-back through `valid/ready`.
4. Reset during a byte and require return to idle-high.

### CRC and packet encoder

1. Validate CRC against a published check vector such as ASCII `123456789` for
   your exact CRC convention.
2. Encode zero-length, ordinary, and maximum-length packets.
3. Decode the resulting UART bytes with the Python library and compare every
   field and payload byte.
4. Corrupt one byte and require Python CRC rejection.

### Capture buffer

1. Capture a ramp with gaps in `sample_valid`; memory must contain only valid
   samples in exact order.
2. Verify first/last address and exact sample count.
3. Trigger while busy and verify the documented rejection/status behavior.
4. Read every entry and compare it with the source scoreboard.
5. Reset while armed, capturing, and complete.

## Hardware check

Capture grounded A0 and at least one known DC level. Send the packet through the
Arty USB-UART, decode it using the permanent Python library, and save a CSV. The
sample indices must be consecutive and the sample count exact.

## Completion evidence

- Passing RTL and Python tests, including a cross-language packet fixture.
- UART timing/baud calculation.
- One decoded hardware capture with metadata and summary statistics.
- Capture-to-host latency measurement; this is diagnostic latency, not sample
  throughput.

## Done when

- [ ] Full-rate acquisition continues while the bounded buffer fills.
- [ ] Captures contain exact ordered samples and starting index.
- [ ] Packets survive RTL-to-Python round-trip with verified CRC.
- [ ] UART reset and back-to-back byte behavior are tested.
- [ ] The host decoder is structured for reuse by Milestone 13 and final qualification.

## What this unlocks

Milestone 08 can characterize the actual BPW34 path from captured samples rather
than guessing from an LED or marketplace specification.
