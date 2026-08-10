# Milestone 02 — Reset and clock-enable foundation

**Time box:** 1-2 days
**Depends on:** [Milestone 01](01-lab-tools-and-contracts.md)
**Produces:** Permanent reset synchronization, periodic enable generation, and
a board heartbeat

## Why this milestone exists

Nearly every later module needs a clean reset and an event that says “advance
now.” Building these once prevents each block from inventing its own counters
or gated clocks. The final design stays on the Arty's 100 MHz clock and advances
slow logic with one-cycle clock-enable pulses.

## Learning goals

- Understand metastability and why an external button is synchronized.
- Distinguish a clock from a clock enable.
- Derive an integer divider from frequency and verify the off-by-one behavior.
- Use parameters and `$clog2` without creating zero-width counters.
- Write assertions for pulse width and interval.

## Permanent modules to write

Suggested files:

```text
rtl/common/reset_sync.sv
rtl/common/clock_enable_gen.sv
rtl/common/heartbeat.sv
rtl/top/foundation_top.sv
sim/tb/tb_reset_sync.sv
sim/tb/tb_clock_enable_gen.sv
```

### `reset_sync`

Suggested contract:

| Port | Direction | Meaning |
|---|---|---|
| `clk` | input | 100 MHz system clock |
| `async_reset_in` | input | Raw external reset request |
| `rst` | output | Synchronized active-high internal reset |

Use a short flip-flop synchronizer. Asynchronous assertion and synchronous
deassertion is a reasonable policy, but you must state and test the exact
behavior. Do not distribute the raw button to the design.

### `clock_enable_gen`

Suggested contract:

| Parameter/port | Meaning |
|---|---|
| `DIVISOR` | Number of `clk` cycles between enable pulses |
| `clk`, `rst` | System timing and synchronous reset |
| `enable` | Exactly one `clk` cycle high every `DIVISOR` cycles |

For a 100 MHz clock:

```text
cycles per event = 100_000_000 / event_rate
10 kHz symbol enable -> 10,000 cycles
250 kHz sample schedule -> 400 cycles
1 Hz heartbeat -> 100,000,000 cycles
```

Use integer rates for V1. A fractional accumulator is an upgrade, not required.

### `heartbeat`

Make a small module that toggles an LED on a slow enable. It stays in the final
top as a visible “clock and reset are alive” indicator, so this is not throwaway
logic.

## SystemVerilog guidance

- A parameterized width often uses `$clog2(DIVISOR)`, but `$clog2(1)` is zero.
  Either reject `DIVISOR < 2` or clamp the width to at least one bit.
- Compare the counter with `DIVISOR-1`; reset it and raise `enable` on that same
  edge. Decide whether the first pulse occurs immediately or after a complete
  interval and test that decision.
- Assign `enable <= 1'b0` on every ordinary cycle so it cannot remain high.
- Use sized constants or casts when comparing a vector to an integer parameter.
- Do not write `always #(period)` in synthesizable RTL; that construct belongs
  only in a testbench clock generator.

## Testbench requirements

### Reset synchronizer tests

1. Assert the raw reset at several offsets relative to the clock edge.
2. Confirm internal reset asserts according to your stated policy.
3. Release the raw input near a clock edge and confirm internal reset releases
   only after the expected synchronization stages.
4. Confirm there is no one-cycle deassert/reassert glitch.

### Clock-enable tests

Use a small `DIVISOR`, such as 4 or 7, so simulation is quick.

1. Count cycles between at least 20 pulses; every interval must equal `DIVISOR`.
2. Assert that an enable never remains high for two adjacent cycles.
3. Apply reset mid-count and verify the documented restart behavior.
4. Instantiate two different divisors simultaneously to prove parameterization.
5. Include an assertion or scoreboard rather than relying only on waveforms.

### Hardware check

Build `foundation_top` with the synchronized button reset and heartbeat LED.
Program it through `scripts/fpga.cmd`. Press reset and confirm the heartbeat
restarts predictably.

## Completion evidence

- Passing simulator transcript for both unit testbenches.
- Synthesis/implementation timing summary with no unconstrained main clock.
- A short table showing requested versus derived enable rates.
- A brief explanation of why a clock enable is preferable to a fabric-generated
  slow clock here.

## Done when

- [ ] Reset is synchronized once and used consistently.
- [ ] Enable pulses have exact width and interval in automated tests.
- [ ] The heartbeat runs and resets on physical hardware.
- [ ] Both modules have comments describing their contracts, not every line.
- [ ] No gated or divided clock has been introduced.

## Common traps

- Counting `DIVISOR` rather than `DIVISOR-1`.
- Forgetting the default low assignment for a pulse.
- Using the pushbutton directly as a synchronous reset everywhere.
- Treating an enable pulse as a clock in another `always_ff` block.

## What this unlocks

Every later state machine can advance on explicit symbol, sample, UART, or
status enables while remaining in one easy-to-constrain clock domain.
