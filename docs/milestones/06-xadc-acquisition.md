# Milestone 06 — Single-channel XADC acquisition

**Time box:** 1-2 days
**Depends on:** [Milestone 02](02-reset-and-clock-enables.md) and the Arty A7-100T
board identification from Milestone 01
**Produces:** One trustworthy stream of 12-bit samples from physical header A0

## What you are actually building

This milestone is an ADC reader, not yet an optical receiver or DSP pipeline.
The finished block repeatedly measures the voltage on the Arty A0 header and
turns each completed conversion into this digital event:

```text
sample_valid = 1 for one 100 MHz clock
sample_u12   = the new 12-bit ADC code
sample_index = the number belonging to that sample
```

Milestone 06 ends at that interface. It does not transmit samples to the PC,
store a long capture, filter them, or use the BPW34. Milestone 07 consumes this
stream and adds capture/UART support.

The reason for the extra logic is that the XADC does not directly produce the
three signals above. It reports that a conversion ended with `EOC`; the FPGA
then reads a status register through the Dynamic Reconfiguration Port (DRP),
waits for `DRDY`, extracts the upper 12 bits of the returned 16-bit word, and
creates `sample_valid`.

## One conversion, walked through

Assume A0 is held near half scale and the XADC has produced code `12'h800`.

1. The hardened XADC converts the A0 voltage internally.
2. XADC raises `EOC` for the completed VAUX4 conversion.
3. Your controller issues a one-clock DRP read:
   `DEN=1`, `DWE=0`, and `DADDR=7'h14`.
4. The controller enters `WAIT_DRDY` and starts a timeout counter.
5. XADC later raises `DRDY` and presents `DO=16'h8000`.
6. Your controller captures `DO[15:4]`, which is `12'h800`.
7. For that clock, it asserts `sample_valid=1` and presents the sample's index.
8. On the following clock, `sample_valid` returns to zero and the controller
   waits for the next `EOC`.

`EOC` means that a conversion result exists. `DRDY` means that the requested
DRP register value is now available. They are related events, but they are not
the same signal and should not be treated as interchangeable.

## Structure and signal flow

```text
physical A0 header
    |
    | board 0-3.3 V scaling network
    v
vaux4_p / vaux4_n FPGA pins
    |
    v
XADC primitive adapter
    |  EOC, DRDY, DO[15:0], BUSY
    v
DRP/sample controller
    |  DEN, DADDR=0x14 returned toward XADC
    |
    +--> sample_u12[11:0]
    +--> sample_valid
    +--> sample_index
    +--> xadc_fault
```

There is only one controller state machine. The hardened XADC has its own
internal conversion sequencer, but that is vendor hardware being configured,
not a second FSM that you write.

## Files and ownership

Use the repository's existing `rtl/models` and `rtl/tb` directories. The older
`sim/models` and `sim/tb` paths were inconsistent with the actual tree.

| File | What belongs in it | What does not belong in it |
|---|---|---|
| `rtl/acquisition/xadc_drp_controller.sv` | The small `WAIT_EOC`/`WAIT_DRDY` FSM, timeout, sample extraction, valid pulse, and index | Pin constraints, voltage arithmetic, or an XADC primitive |
| `rtl/acquisition/xadc_single_channel.sv` | A thin hardware-only adapter around AMD's `XADC` primitive, configured for VAUX4/A0 | Capture RAM, UART, filters, or test stimulus |
| `rtl/models/xadc_model.sv` | A behavioral replacement that produces `EOC`, delayed `DRDY`, and packed `DO` data | Analog photodiode physics or synthesizable hardware |
| `rtl/tb/tb_xadc_drp_controller.sv` | Drives chosen codes and latency into the model, then checks the controller | Board pin behavior |
| `rtl/top/xadc_bringup_top.sv` | Reset synchronization, primitive adapter, controller, and a few LED diagnostics | The later UART/capture implementation |
| `constraints/xadc_bringup_top.xdc` | A0 analog pins and bring-up LED mappings | XADC register configuration |
| `docs/hardware/xadc-interface.md` | Configuration table, rate calculation, voltage equation, measurements, and limitations | RTL source code |

`sample_index.sv` is not required for this project. Keeping the counter in the
controller makes the timing relationship unambiguous. Split it out only if a
later design has more than one producer that needs the same counter logic.

There are currently empty placeholder files named
`rtl/acquisition/xadc_single_channel.sv`, `rtl/models/xadc_model.sv`, and
`rtl/top/xadc_beingup_top.sv`. Rename the misspelled `beingup` file to
`xadc_bringup_top.sv` before implementing it.

## Interface between the adapter and controller

Keep the vendor-specific primitive signals on one side and the reusable sample
stream on the other. A suitable controller interface is:

```systemverilog
module xadc_drp_controller #(
    parameter int unsigned TIMEOUT_CYCLES = 256,
    parameter int unsigned INDEX_WIDTH = 64
)(
    input logic clk,
    input logic rst,

    input logic xadc_eoc,
    input logic xadc_drdy,
    input logic [15:0] xadc_do,
    output logic xadc_den,
    output logic [6:0] xadc_daddr,

    output logic [11:0] sample_u12,
    output logic sample_valid,
    output logic [INDEX_WIDTH-1:0] sample_index,
    output logic xadc_busy,
    output logic xadc_fault
);
```

The adapter connects `xadc_den`, `xadc_daddr`, `xadc_eoc`, `xadc_drdy`, and
`xadc_do` to the corresponding primitive ports. Tie the primitive's DRP write
enable low because this controller only reads conversion results.

Define the sample-index rule before writing code:

- the first accepted sample has index zero;
- while `sample_valid=1`, `sample_u12` and `sample_index` describe the same
  newly accepted sample; and
- the next index advances exactly once for every `DRDY` that completes a valid
  outstanding read.

A private `next_index` register is the least confusing implementation. On a
successful `DRDY`, copy `next_index` to the output index and then increment
`next_index` for the following sample.

## Controller FSM

Only two normal states are needed:

```text
              xadc_eoc
    +---------- yes -----------+
    |                          v
+-----------+             +-----------+
| WAIT_EOC  |             | WAIT_DRDY |
| DEN = 0   |             | timeout++ |
+-----------+             +-----------+
    ^                          |
    |       xadc_drdy           |
    +--- capture DO[15:4] ------+
         pulse sample_valid
```

Behavior by state:

| State | Required behavior |
|---|---|
| `WAIT_EOC` | `sample_valid=0`; when `xadc_eoc=1`, pulse `xadc_den`, drive address `7'h14`, clear the transaction timeout, and enter `WAIT_DRDY` |
| `WAIT_DRDY` | Keep `sample_valid=0`; on `xadc_drdy`, capture `xadc_do[15:4]`, assign the index, pulse `sample_valid`, and return to `WAIT_EOC` |
| Timeout | If `DRDY` does not arrive within `TIMEOUT_CYCLES`, set sticky `xadc_fault=1` and return to a defined safe state |
| Reset | Clear the FSM, timeout, sample output, valid pulse, index, and sticky fault |

`xadc_den` and `sample_valid` should default low every clock and only pulse high
in the exact event branch that creates them. If another `EOC` appears while a
DRP read is outstanding, treat it as an impossible/overrun condition and set
the sticky fault rather than silently starting a second read.

`xadc_busy` in this milestone means that the controller has an outstanding DRP
read. The primitive's own `BUSY` output may be exposed separately as a debug
signal; do not combine two meanings under one name.

## XADC primitive adapter

The adapter is the only file allowed to know AMD primitive details. It should:

- instantiate the 7-series `XADC` primitive;
- connect system clock `clk_100mhz` to `DCLK`;
- connect reset to the primitive `RESET` input;
- place VAUX4 in unipolar, single-channel continuous-conversion operation;
- disable sample averaging for the first bring-up;
- use the on-chip reference selected for this board design;
- connect top-level `vaux4_p` and `vaux4_n` into bit 4 of the primitive's
  16-channel `VAUXP` and `VAUXN` buses, tying unused bits low;
- connect `DEN`, `DADDR`, `DO`, `DRDY`, `EOC`, and primitive `BUSY`; and
- intentionally tie unused alarms, writes, `CONVST`, and external-multiplexer
  functions to documented values.

Do not guess the `INIT_40` through `INIT_5F` attribute values. Use the XADC
primitive template or XADC Wizard as a configuration calculator, record the
resulting values in `docs/hardware/xadc-interface.md`, and keep the final
checked-in adapter readable. The checked-in RTL remains the source of truth;
a large block design is not required.

AMD documents VAUX conversion results at DRP addresses `0x10` through `0x1F`.
VAUX4 therefore uses `7'h14`. The result is MSB-justified, so the normalized
sample is `xadc_do[15:4]`, not `xadc_do[11:0]`.

## Clock and expected sample rate

The 100 MHz board clock is the XADC `DCLK`. The primitive's clock divider
creates `ADCCLK`:

```text
ADCCLK = 100 MHz / XADC_CLOCK_DIVIDER
nominal continuous sample rate = ADCCLK / 26
```

For example, a divider of 16 gives:

```text
ADCCLK = 6.25 MHz
nominal sample rate = 6.25 MHz / 26 = about 240.4 kSa/s
```

That is close to the project's 250 kSa/s target and remains comfortably above
the planned 10 kbit/s optical rate. Treat this as the expected value, not a
measurement: count real `sample_valid` pulses over a known interval and record
the observed rate. If extended acquisition time is enabled, include its extra
cycles in the calculation.

Do not create a fabric-generated XADC clock. Keep `DCLK` on the existing
100 MHz clock and use the primitive's supported divider.

## Top-level responsibilities

`xadc_bringup_top.sv` is glue, not another protocol controller. It should:

1. accept `clk_100mhz`, `reset_btn`, `vaux4_p`, and `vaux4_n`;
2. instantiate the existing `reset_sync`;
3. instantiate `xadc_single_channel`;
4. instantiate `xadc_drp_controller`;
5. connect the two internal interfaces directly; and
6. expose simple diagnostics such as `sample_seen`, activity, and `xadc_fault`
   on LEDs.

The sample stream can remain internal in this bring-up top. One useful LED
policy is:

| LED behavior | Meaning |
|---|---|
| `sample_seen_led` latches on | At least one sample completed since reset |
| `sample_activity_led` toggles after a large number of valid samples | Acquisition continues to run; do not drive an LED directly with a one-cycle pulse |
| `xadc_fault_led` latches on | The controller timed out or observed an impossible event |
| `sample_level_led` | Optional: high when the latest code is above half scale |

The LEDs prove life and gross voltage response. They cannot prove exact codes;
exact sample capture is added in Milestone 07 or may be inspected temporarily
with Vivado ILA.

## A0 wiring and constraints

Physical Arty header A0 is one 0-3.3 V single-ended input plus board ground. The
board's resistor network turns it into the internal VAUX4 differential pair;
you do not externally wire separate positive and negative A0 signals.

For the Arty A7-100 Rev. D/E master XDC, use:

```tcl
# ChipKit A0 through the board's single-ended 0-3.3 V scaling network
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_p]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_n]
```

Put these in `constraints/xadc_bringup_top.xdc`. The common clock and reset stay
in `constraints/arty_a7_100t_base.xdc`. Do not simultaneously constrain A0 as a
digital `ck_a0` pin.

## Raw-code voltage meaning

Keep volts out of synthesizable RTL. The nominal host/documentation conversion
for the board's 0-3.3 V A0 path is:

```text
expected_code = round((applied_voltage / 3.3 V) * 4095)
estimated_voltage = sample_u12 * 3.3 V / 4095
```

Useful approximate checkpoints are:

| Applied A0 voltage | Expected ideal code |
|---:|---:|
| 0.000 V | `0x000` |
| 0.825 V | `0x400` |
| 1.650 V | `0x800` |
| 2.475 V | `0xBFF` |
| 3.300 V | `0xFFF` |

These are ideal values. Resistor tolerance, reference error, offset, source
impedance, and noise produce variation, which is why actual measurements belong
in `docs/hardware/xadc-interface.md`.

## Behavioral model

`xadc_model.sv` is not an analog simulator. It mimics only the digital contract
needed to test your FSM. Give it test-only controls such as:

- a 12-bit code supplied by the testbench;
- a request to emit an `EOC` event;
- a configurable delay between `DEN` and `DRDY`; and
- a `stall_drdy` input for timeout testing.

When it returns a code, pack it exactly as the real status register does:

```systemverilog
xadc_do = {model_code, 4'b0000};
```

The model should check that the controller requested `DADDR=7'h14` and did not
assert the write enable. It does not need real-number voltages, a photodiode
model, or the AMD primitive library.

## Testbench checklist

Build the testbench around `xadc_drp_controller + xadc_model`, not the hardware
top. Use a small timeout and index width so corner cases run quickly.

1. Reset and verify no valid pulse, no fault, and index starts at zero.
2. Return `0x000`, `0x001`, `0x800`, and `0xFFF`; compare every sample exactly.
3. Verify each model code was returned as the upper 12 bits of `DO`.
4. Vary DRP latency, including immediate and near-timeout responses.
5. For every injected conversion, count exactly one `sample_valid` pulse.
6. Check that valid is never high for two consecutive clocks.
7. Check indices `0, 1, 2, 3...` with no duplicates or gaps.
8. Hold `DRDY` off beyond the timeout and require sticky `xadc_fault`.
9. Reset while waiting for `EOC` and while waiting for `DRDY`.
10. Inject an unexpected second `EOC` during `WAIT_DRDY` and verify the chosen
    overrun/fault policy.

Useful assertions include:

```systemverilog
assert property (@(posedge clk) disable iff (rst)
    sample_valid |-> !$past(sample_valid));
assert property (@(posedge clk) disable iff (rst)
    xadc_den |-> (xadc_daddr == 7'h14));
```

The first property needs an exception if the design can legitimately accept a
new conversion every system clock; this XADC design cannot, so it is useful.

## Recommended implementation order

Do not try to write all files at once.

1. Write the controller interface and the two-state FSM.
2. Write the behavioral model.
3. Write and pass the controller/model testbench.
4. Write the thin XADC primitive adapter using verified vendor settings.
5. Write the bring-up top and LED diagnostics.
6. Add the A0 and LED constraints.
7. Run synthesis, implementation, timing, and bitstream generation.
8. With A0 grounded, program the board and check `sample_seen` with no fault.
9. Apply two or more measured safe DC voltages and check monotonic response.
10. Record the configuration and measurements in
    `docs/hardware/xadc-interface.md`.

This order proves your logic with deterministic codes before introducing the
vendor primitive, pin constraints, and real analog noise.

## Electrical test sequence

Do not attach the BPW34 yet.

1. Connect a board GND pin to the source ground.
2. Start with A0 connected to ground through an appropriate resistor.
3. Program the bring-up bitstream and confirm samples arrive without a fault.
4. Apply at least two known voltages between 0 and 3.3 V from a safe source or
   divider, measuring each with a multimeter.
5. For every voltage, record mean code, minimum, maximum, and sample count.
6. Confirm that increasing voltage increases code and that values are near the
   nominal equation above.
7. Count `sample_valid` events over a known interval to measure samples/second.
8. Remove the test source before changing wiring.

Never exceed 3.3 V at physical A0. The 0-3.3 V statement applies specifically
to the Arty A0-A5 board paths with their scaling networks; it does not apply to
the direct A6-A11 XADC differential inputs.

## Completion evidence

- A passing controller/model testbench transcript with code, latency, reset,
  overrun, and timeout cases.
- A wrapper configuration table that identifies every non-default XADC choice.
- The exact A0/VAUX4 constraint excerpt.
- Synthesis, timing, DRC, and bitstream evidence for `xadc_bringup_top`.
- A voltage table containing applied voltage, expected code, measured mean,
  minimum, maximum, and number of samples.
- Measured samples per second and the expected-rate calculation.
- A note that the BPW34 was not used for this electrical ADC validation.

## Done when

- [x] Each completed conversion creates exactly one one-clock
  `sample_valid` pulse.
- [x] `sample_u12` is exactly the XADC status word's `DO[15:4]`.
- [x] The first sample index is zero and later indices have no gaps or repeats.
- [x] Reset cancels an outstanding transaction and returns all diagnostics to a
  documented state.
- [x] A missing `DRDY` produces a sticky, visible timeout fault.
- [ ] Ground and at least two measured DC inputs produce monotonic, plausible
  codes.
- [ ] The physical sample rate is measured and explained.
- [ ] The configuration, constraints, measurements, and limitations are
  recorded in `docs/hardware/xadc-interface.md`.

## Common mistakes

- Reading `DO[11:0]` instead of the MSB-justified `DO[15:4]`.
- Reading address `0x04` instead of VAUX4 status address `0x14`.
- Treating `EOC` as if it already were `sample_valid`; the DRP read must finish.
- Holding `DEN` high while waiting for `DRDY` instead of issuing one request.
- Incrementing the index on `EOC` rather than on accepted `DRDY` data.
- Calculating floating-point volts in synthesizable RTL.
- Driving an LED directly from a one-cycle valid pulse, making activity appear
  absent to a human observer.
- Constraining A0 as both analog VAUX4 and digital `ck_a0`.
- Testing the photodiode before a known voltage proves the ADC path.

## Primary references

- [AMD UG480: 7 Series XADC User Guide](https://docs.amd.com/r/en-US/ug480_7Series_XADC)
- [AMD UG953: XADC primitive](https://docs.amd.com/r/2024.2-English/ug953-vivado-7series-libraries/XADC)
- [Digilent Arty A7-100 master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Arty-A7-100-Master.xdc)
- Local [Arty reference manual](../datasheets/arty_rm.pdf)
- Local [Arty schematic](../datasheets/arty-a7-e2-sch.pdf)

## What this unlocks

Milestone 07 can retain bounded sample windows and send them to the PC. That is
the evidence path later used to characterize the BPW34 receiver in Milestone 08.
