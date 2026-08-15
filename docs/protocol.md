# Optical-link protocol conventions

## V1 optical frame convention

| Field | Width | Frozen value/source | Bit order |
|---|---:|---|---|
| Alternating preamble | 32 bits | `32'hAAAAAAAA` | MSB first; begins with `1` |
| Sync word | 16 bits | `16'hD5B3` | MSB first |
| Frame sequence | 16 bits | Starts at zero and increments after each completed frame | MSB first |
| PRBS-15 payload | 1024 bits | Reload `15'h0001` at every payload start | Current PRBS output before advance |

The complete frame is 1088 transmitted symbols. Logical `1` commands the
laser on and logical `0` commands it off. Reset forces the logical transmitter
output low, resets the sequence to zero, and parks the framer at preamble bit
zero.

Transmit modes are `OFF`, `ON`, `TRAINING`, and `FRAMED`. A mode request takes
effect immediately. Leaving `FRAMED` aborts the partial frame, and returning to
`FRAMED` starts a new frame at preamble bit zero. Entering `TRAINING` restarts
the alternating pattern at `1`. All symbol state advances only on `symbol_ce`.

## PRBS-15 payload convention

The payload source and checker use one frozen PRBS-15 convention so that the
transmitter, receiver, testbenches, and later BER engine generate identical bit
ordering.

| Item | Frozen value |
|---|---|
| Polynomial | `x^15 + x^14 + 1` |
| State | `state[14:0]` |
| Seed | `15'h0001` |
| Shift direction | Toward increasing indices: old `state[13]` becomes new `state[14]` |
| Feedback | Old `state[14] ^ state[13]` |
| Feedback insertion | New `state[0]` |
| Serialized output | Current `state[14]` |
| Observation | Output is observed before the state advances |
| Advance event | One state transition on an asserted `advance` at `posedge clk` |
| Control priority | `rst`, then `load_seed`, then zero-state recovery, then `advance`, otherwise hold |
| Zero state | Illegal; defensively replaced with `15'h0001` on the next clock |
| Payload policy | Assert `load_seed` at the start of every optical payload |

The state transition is equivalent to:

```systemverilog
state[14] <= state[13];
state[13] <= state[12];
// Continue shifting each bit toward state[14].
state[1]  <= state[0];
state[0]  <= state[14] ^ state[13];
```

From `15'h0001`, the first 32 serialized bits are:

```text
00000000000000100000000000001100
```

The fixed 64-bit generator-test vector is:

```text
0000000000000010000000000000110000000000001010000000000011110000
```

### Why the maximum-length period matters

A maximal PRBS-15 visits every one of its 32,767 nonzero states before
repeating. That long repeat interval exercises varied runs and transitions
instead of testing the optical path with a short, repetitive pattern. For BER
measurements it also gives the transmitter and checker a deterministic expected
sequence over long captures, while a premature recurrence would reduce pattern
coverage and could hide data-dependent link faults. The zero state is excluded
because it would produce zeros forever and therefore provide no useful link
stress.

## V1 host UART packet convention

Milestone 7 adds a diagnostic host transport that is independent of the optical
frame above. Its byte layout is:

```text
A5 5A | 01 | type | payload_length_le[2] | sequence_le[2] | payload | crc_le[2]
```

The maximum payload is 4,096 bytes. Type `02` carries a sample capture. The CRC
is CRC-16/CCITT-FALSE with polynomial `0x1021`, initial value `0xFFFF`, no input
or output reflection, and no final XOR. It covers every byte beginning with the
version and ending with the payload; sync and CRC bytes are excluded. The
published ASCII `123456789` check value is `0x29B1`.

Capture payload type `02` is:

```text
start_index_le[8] | sample_count_le[2] | format[1] | sample_u16_le[count]
```

Format `01` stores each unsigned 12-bit XADC code in bits 11:0 of a 16-bit
little-endian field. The Python streaming decoder resynchronizes by searching
for `A5 5A`; after an invalid length or CRC it advances one byte and repeats the
search.
