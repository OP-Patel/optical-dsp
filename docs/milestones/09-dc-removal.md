# Milestone 09 — Fixed-point DC removal

**Time box:** 1-2 days
**Depends on:** [Milestone 08](08-bpw34-analog-link.md)
**Produces:** A bit-true baseline-restoration stage using the shared sample
interface

## Why this milestone exists

Ambient light and alignment create a DC offset that can move the off/on levels
without carrying data. Removing a slowly varying baseline makes later threshold
and FIR behavior easier to reason about. This is the first fixed-point DSP block,
so the emphasis is numeric clarity: widths, signedness, rounding, saturation,
latency, and reset transient must all be explicit.

## Chosen simple algorithm

Use a first-order running estimate:

```text
error[n]       = x[n] - dc_estimate[n]
dc_estimate[n+1] = dc_estimate[n] + error[n] / 2^K
y[n]           = x[n] - dc_estimate[n]
```

Division by `2^K` becomes an arithmetic right shift. `K` controls how slowly
the estimate follows the signal. A larger `K` preserves data transitions but
takes longer to settle. Choose the baseline `K` from measured sample rate and
desired time constant, then freeze it in the design note.

For balanced OOK, the running mean lies near the midpoint rather than the laser-
off level. That is acceptable: the output becomes roughly bipolar, which is
useful for filtering and a near-zero threshold.

## Frozen implementation contract

The baseline implementation uses `K=10` and ten fractional estimate bits. At
the measured `240384.615` sample/s rate, one estimator time constant is about
`1023.5` samples or `4.258 ms`. Five time constants are about `21.29 ms`; the
conservative full-range bring-up wait is `40 ms` after reset.

| Quantity | Representation | Numeric range |
|---|---|---:|
| XADC input | unsigned 12-bit integer | 0 to 4095 |
| Input in estimator units | signed 23-bit Q12.10 | 0 to 4,193,280 |
| DC estimate | unsigned 22-bit Q12.10 | 0 to 4,193,280 |
| Estimator error | signed 23-bit Q12.10 | -4,193,280 to +4,193,280 |
| Estimate update | signed 23-bit Q12.10 | -4095 to +4095 |
| Next-estimate check | signed 24-bit Q12.10 | guard bit prevents wrap |
| Centered output | signed 13-bit integer | -4095 to +4095 |
| Debug estimate | unsigned 12-bit integer | 0 to 4095 |

The estimate update is an arithmetic right shift. This means a negative update
rounds toward negative infinity, which is bit-exact and avoids an unsigned
conversion. The centered output is independently rounded to nearest, with a
half-code rounded away from zero. It is calculated from the pre-update estimate
and registered, so `out_valid` and `out_sample` appear one system-clock cycle
after the matching `in_valid`/`in_sample`. Invalid input clocks do not update any
filter state.

An out-of-range next estimate saturates to 0 or full scale and raises the sticky
`estimate_fault`. The legal 12-bit input sequences in the unit test never raise
that fault. `clear_estimate` resets the estimate, output-valid state, and fault;
`freeze_estimate` holds the estimate while centered samples continue.

## Measured Milestone 08 input contract

The selected physical receiver is `pd02` with a 100 kΩ external load at 7.4 cm
distance. Ten DC pairs measured aggregate OFF/ON means of 13.660 and 16.086
codes. Ten 10 kbit/s captures recovered a mean 2.390-code alternating
separation with approximately 24.038 samples/symbol and no rail clipping.

These values define the nominal test case, but this block must still handle the
entire unsigned 12-bit range safely. Do not reduce the datapath width merely
because the first passive receiver operates near code 15.

## Permanent modules to write

```text
rtl/dsp/dc_removal.sv
rtl/tb/tb_dc_removal.sv
```

Suggested interface:

| Port | Meaning |
|---|---|
| `in_valid` | New unsigned 12-bit XADC sample |
| `in_sample` | Raw XADC code |
| `clear_estimate` | Start a new calibration/run |
| `freeze_estimate` | Optional diagnostic control |
| `out_valid` | Processed sample is valid |
| `out_sample` | Signed centered result |
| `dc_estimate_dbg` | Truncated/debug estimate for status/capture |

## Fixed-point design work

Do this on paper before RTL:

1. Choose the number of fractional bits in the DC estimate. At least `K`
   fractional bits avoids losing every small update.
2. Extend the 12-bit unsigned input to a signed representation safely.
3. Bound the largest positive and negative error.
4. Choose accumulator width with guard bits so startup and full-scale steps
   cannot wrap.
5. Define how the signed output is rounded/truncated and its final width.
6. Define saturation behavior; signal-path wraparound is not allowed.

A useful representation is an estimate stored in “sample units plus fractional
bits.” Shift the input left by the fractional-bit count before subtraction. The
guide intentionally does not freeze the final widths—you should derive them and
justify the result from the 0..4095 input range.

## SystemVerilog guidance

- Unsigned `logic [11:0]` does not become a correct positive signed number just
  because it is passed to `$signed`; prepend a zero before interpreting it as
  signed.
- Arithmetic right shift requires a signed left operand (`>>>`).
- Size intermediate expressions explicitly. SystemVerilog expression width can
  otherwise be smaller than the destination.
- Update state only on `in_valid`; gaps in samples must not alter the estimate.
- Pipeline latency may be one or two valid samples. Choose readability over a
  single giant expression and document the alignment of `out_valid`.
- A parameter such as `K` is useful, but avoid parameterizing every width before
  the baseline is understood.

## Reference vectors

Create expected results independently for small, hand-checkable cases:

- constant zero;
- constant midscale;
- a step from 1000 to 3000;
- alternating 1000/3000;
- maximum and minimum codes;
- valid samples separated by idle cycles.

Use a spreadsheet, calculation table, or small host-side reference function to
generate longer expected vectors. The reference must implement the documented
fixed-point order and rounding, not an ideal floating-point filter.

## Testbench requirements

1. Compare every output sample with a bit-exact expected vector.
2. Prove constant input settles toward zero-centered output within a declared
   tolerance and time.
3. Confirm alternating OOK is preserved after initial settling.
4. Apply a slow DC ramp and show the estimate follows while fast transitions
   remain.
5. Insert random valid gaps and verify state changes only on valid input.
6. Exercise clear/freeze controls.
7. Assert that no internal overflow or output wrap occurs for all 12-bit extreme
   sequences used in the test.
8. Verify output-valid latency exactly.

## Hardware verification

Add capture selection so the diagnostic buffer can capture either raw XADC,
DC estimate, or centered output. Use the nominal and degraded hardware settings
from Milestone 08.

Verify:

- the raw on/off structure is still recognizable;
- the centered long-term mean is near zero after warm-up;
- no clipping/saturation flag appears; and
- blocking/unblocking the beam produces a documented transient and recovery.

### Milestone 09 bring-up controls

The separate `dc_removal_bringup_top` keeps the accepted Milestone 08 image
unchanged. BTN3 cycles the requested capture source while the capture path is
idle. RGB LED0 identifies the source: red is raw XADC, green is the rounded DC
estimate, and blue is centered output. BTN1 latches that choice and arms the
capture; BTN2 triggers it. A BTN3 press while armed, capturing, or streaming is
rejected and lights the fault LED.

BTN0 resets and therefore clears the estimator. The standalone block's
`freeze_estimate` control is verified in simulation but tied low in this
bring-up top; no extra physical switch is consumed for it.

Centered samples are transported through the existing unsigned 12-bit packet
as offset binary. Decode every CSV `raw_code` with:

```text
centered_signed = raw_code - 2048
```

Values outside the packet's -2048 to +2047 diagnostic range saturate and set
the sticky fault LED for that capture. This affects only the diagnostic copy; the permanent signed
13-bit DSP output retains its full -4095 to +4095 range.

## Completion evidence

- Width/range table for every internal quantity.
- Chosen `K`, approximate time constant in samples/seconds, and rationale.
- Passing bit-exact unit test with overflow assertions.
- Before/after plots from the same physical capture.
- Measured warm-up duration used by later benchmarks.

## Done when

- [ ] The block is bit-exact against an independent reference.
- [ ] Signedness, rounding, latency, and saturation are documented.
- [ ] Constant offset is removed without erasing the 10 kbit/s pattern.
- [ ] Hardware captures show no unexpected wrap or clipping.
- [ ] Downstream blocks see only the common valid/sample interface.

## What this unlocks

Milestone 10 can filter a centered signed signal with a clear numeric envelope.
