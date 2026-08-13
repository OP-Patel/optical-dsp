# Milestone 10 — Readable fixed-point FIR filter

**Time box:** 2 days
**Depends on:** [Milestone 09](09-dc-removal.md)
**Produces:** A parameterized, direct-form FIR whose behavior and numeric growth
you can explain tap by tap

## Why this milestone exists

The FIR stage demonstrates a core FPGA DSP pattern: delayed samples,
fixed-point coefficients, parallel products, accumulation, rounding, and
saturation. The baseline favors a readable direct-form architecture over the
smallest or fastest implementation. At 250 kSa/s on an Arty A7, there is ample
time and hardware for a straightforward design.

## Baseline architecture

For `TAPS` coefficients:

```text
y[n] = sum from k=0 to TAPS-1 of h[k] * x[n-k]
```

Use a sample shift register and multiply each stored sample by a constant signed
coefficient. Sum into a deliberately wide accumulator, then apply one defined
rounding and saturation operation.

Start with a small, explainable coefficient bank:

- bypass/identity for integration checking;
- short moving-average or pulse-smoothing response;
- one measured/model-derived receive filter intended to improve a degraded
  optical condition.

Use 8 taps first if it makes hand verification easier; keep `TAPS` parameterized
and qualify a 16-tap configuration before final completion. Runtime arbitrary
coefficient writes are not required. A host-selected compile-time bank is
sufficient for V1.

## Permanent modules to write

```text
rtl/dsp/fir_filter.sv
rtl/dsp/round_saturate.sv       # reusable if kept independently clear
rtl/dsp/fir_coefficients.sv     # package or read-only bank
sim/tb/tb_fir_filter.sv
sim/tb/tb_round_saturate.sv
```

Suggested interface:

| Port | Meaning |
|---|---|
| `in_valid`, `in_sample` | Signed centered sample stream |
| `filter_enable` | Select filtered or latency-matched bypass output |
| `coeff_bank` | Select one preverified coefficient set |
| `out_valid`, `out_sample` | Signed filtered stream |
| `saturation_pulse` | A result exceeded representable output range |

If bypass and filtered paths have different latency, delay the bypass so mode
changes do not silently change sample alignment.

## Fixed-point work before coding

Create a table containing:

- input width and maximum magnitude from Milestone 09;
- coefficient format, such as signed Q1.15;
- full product width;
- worst-case sum bound using `sum(abs(h[k])) * max(abs(x))`;
- accumulator width and guard bits;
- output scaling shift;
- rounding policy for positive and negative values; and
- saturation endpoints.

Do not rely on “the coefficients usually sum to one.” The bound must remain safe
for every available coefficient bank.

## SystemVerilog guidance

- Packed and unpacked arrays have different syntax. A sample delay line is often
  an unpacked array of packed signed values.
- Declare samples and coefficients `signed` at their source. Mixed signed and
  unsigned multiplication is a common silent bug.
- A `for` loop in synthesizable RTL describes replicated hardware when used for
  all taps in one cycle; it is not a software loop that consumes clock cycles.
- Decide whether the newest input participates in the output on the same valid
  event or one event later. Use an impulse test to freeze this convention.
- Nonblocking assignments mean a shift-register element read in the same
  `always_ff` cycle contains its old value. Account for this intentionally.
- Consider separating product/sum combinational logic from registered output for
  readability. If timing later fails, add a documented pipeline stage rather
  than rewriting the algorithm.
- A coefficient array constant or package is easier to review than scattered
  literals.

## Testbench requirements

### Arithmetic primitive

Test rounding/saturation separately with values just below, at, and beyond both
limits. Include negative halfway cases because arithmetic shifts round toward
negative infinity unless corrected.

### FIR

1. Impulse input: output must reproduce coefficients in exact order and scale.
2. Constant input: settled output must match input times coefficient sum.
3. Alternating maximum/minimum input: exercise signed products and accumulator.
4. A short hand-calculated vector: compare every tap contribution and result.
5. Random deterministic vectors: compare against an independent bit-true model.
6. Valid gaps: delay line advances only on real samples.
7. Bypass: output values and latency align with the filtered path contract.
8. Bank changes: apply only at reset or a declared safe boundary, then verify no
   mixed-coefficient output.
9. Force saturation and require an exact pulse/count.

## Hardware verification

Use the same stored raw/DC-removed capture for filter-off and filter-on analysis
where possible. This removes physical drift from early comparison.

Record:

- on/off level separation and noise before/after;
- impulse/step response from simulation;
- added valid-sample latency;
- LUT, flip-flop, and DSP usage for 8 and 16 taps; and
- maximum clock timing slack after synthesis/implementation.

The filter does not pass merely because the plot looks smoother. It must preserve
framing-relevant transitions and later demonstrate equal or better BER under a
controlled condition.

## Completion evidence

- Fixed-point range table and coefficient-bank table.
- Passing impulse, hand-vector, random-vector, saturation, and gap tests.
- Resource/timing comparison for 8 and 16 taps.
- Physical before/after capture using identical raw input or paired conditions.

## Done when

- [ ] Every coefficient appears in the correct impulse-response order.
- [ ] Bit-exact results match an independent reference.
- [ ] No internal wraparound is possible under documented bounds.
- [ ] Bypass and filter latency are explicit and tested.
- [ ] Both 8- and 16-tap configurations meet 100 MHz timing.

## Scope guard

Do not implement adaptive coefficients, a serial MAC optimization, or a vendor
FIR IP in V1. The point is to understand and explain the datapath you wrote.

## What this unlocks

Milestone 11 can select one sample per symbol and decide bits from a stable,
centered, optionally filtered stream.
