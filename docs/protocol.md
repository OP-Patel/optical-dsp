# Optical-link protocol conventions

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
