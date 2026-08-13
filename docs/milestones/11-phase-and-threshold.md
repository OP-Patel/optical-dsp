# Milestone 11 — Sample phase and threshold decision

**Time box:** 2 days
**Depends on:** [Milestone 10](10-fir-filter.md)
**Produces:** A training-assisted calibration block and one valid decided bit per
symbol

## Why this milestone exists

At 10 kbit/s and 250 kSa/s, the receiver sees 25 candidate samples for each
symbol. Some lie near optical transitions; others lie near the stable center.
This milestone uses the permanent alternating training mode to choose a good
integer sample phase and threshold, then emits one decision per symbol in framed
mode. It is intentionally not a claim of independent-clock carrier recovery:
TX and XADC ultimately share the Arty reference.

## Simple calibration strategy

During continuous `TRAINING` mode, the transmitter and receiver share the symbol
counter and know whether each symbol was commanded on or off.

The expected training bit must be aligned with the processed sample. XADC
capture, DC removal, and FIR stages each declare latency in valid samples. Delay
the expected-bit reference by their summed digital latency before classifying a
sample as commanded-on or commanded-off. The remaining optical/electrical delay
is what the 25-phase scan measures. Without this alignment, a correct FIR delay
can look like inverted or poor optical separation.

For every phase `p` from 0 to 24:

1. Accumulate filtered samples that correspond to commanded-on symbols.
2. Accumulate samples that correspond to commanded-off symbols.
3. Collect an equal power-of-two number of each, such as 16 or 32.
4. Compute `mean_on[p]` and `mean_off[p]` with a shift.
5. Score the phase using `mean_on[p] - mean_off[p]`.
6. Select the largest positive score.
7. Set the threshold to the midpoint of that phase's means.

Latch the selected phase and threshold when calibration completes. They remain
stable while framed data is received. A host command can request recalibration
later through the control plane.

This training-assisted approach is a permanent design feature, not a throwaway
shortcut. It is also honest: it measures sample-phase selection on a
common-reference link, not asynchronous clock recovery.

## Permanent modules to write

```text
rtl/sync/phase_counter.sv
rtl/sync/valid_event_delay.sv       # align training reference with DSP latency
rtl/sync/training_calibrator.sv
rtl/sync/symbol_decider.sv
sim/tb/tb_training_calibrator.sv
sim/tb/tb_symbol_decider.sv
```

Suggested calibrator status:

| Signal | Meaning |
|---|---|
| `cal_start` | Clear and begin a new training measurement |
| `training_expected_bit` | Known commanded training symbol |
| `sample_phase` | Current sample index within the symbol |
| `cal_done` | Selected phase/threshold are valid |
| `best_phase` | Integer phase `0..SPS-1` |
| `threshold` | Signed decision boundary in filter-output units |
| `quality_score` | Selected mean separation for status |
| `cal_fault` | Insufficient/negative separation or timeout |

Suggested decider behavior:

- On each filtered valid sample whose phase equals `best_phase`, compare sample
  with threshold.
- Emit one-cycle `bit_valid` and a decided `bit_out`.
- Emit no bit until calibration is valid and receive mode is enabled.

## Width and state planning

Before coding, bound:

- filter-output width and magnitude;
- number of samples accumulated per phase/level;
- sum width, including sign and `ceil(log2(count))` growth;
- midpoint addition width; and
- score width.

Twenty-five phase entries are small enough for arrays of registers. Favor
clarity over forcing block RAM. Process one phase comparison per clock over 25
cycles after collection instead of constructing a large combinational maximum
tree.

## SystemVerilog guidance

- Use an array for on/off sums indexed by phase. Resetting all entries with a
  loop is clear, but verify synthesis cost and reset behavior.
- Non-power-of-two phase wrap at 25 requires an explicit terminal comparison;
  natural binary overflow will wrap at 32, not 25.
- Dividing equal power-of-two sample counts is a shift. Midpoint division by two
  needs defined signed rounding.
- Separate collection from evaluation with explicit states such as `IDLE`,
  `COLLECT`, `SCAN`, and `DONE`.
- The sample-phase counter advances only on `sample_valid`, while the expected
  training bit advances only at the symbol boundary. Prove their relationship.
- Build the reference delay in units of accepted samples, not raw 100 MHz clock
  cycles, so gaps in `sample_valid` cannot misalign metadata and data.
- A comparison such as `sample >= threshold` defines tie behavior; document it.
- Configuration results crossing into the decider are stable registers, not a
  clock-domain crossing.

## Testbench requirements

Build an oversampled channel model that creates known on/off levels plus:

- a programmable transition region;
- a known best phase;
- DC offset;
- deterministic noise values; and
- optional inversion or inadequate separation.

Tests:

1. For all 25 possible ideal best phases, require the selected phase to equal
   the expected stable region or an explicitly accepted adjacent phase.
2. Verify threshold equals the documented midpoint under noiseless levels.
3. Add bounded noise and confirm phase/threshold remain stable.
4. Add DC offset and show the decision remains correct with DC removal enabled.
5. Present inverted polarity or near-zero separation and require `cal_fault`.
6. Verify timeout if training samples stop arriving.
7. After calibration, send a known bit sequence and require exactly one decision
   per symbol with exact valid timing.
8. Change `best_phase` only via a completed new calibration; no partial result
   may affect live decisions.
9. Sweep the declared upstream pipeline latency and prove delayed reference bits
   remain aligned through valid gaps.

## Hardware verification

1. Command OFF/ON captures and confirm polarity.
2. Run training calibration at 1 kbit/s, then at 10 kbit/s.
3. Capture the chosen phase, threshold, quality score, and per-phase scores if
   diagnostic bandwidth permits.
4. Compare the chosen sample position with the raw training waveform.
5. Repeat after blocking/re-aligning and under the frozen degraded condition.
6. Verify decided training bits over a long run before enabling framed mode.

## Completion evidence

- Width table and calibration-state diagram.
- Automated phase sweep across all 25 candidate phases.
- Hardware phase/threshold/quality values for nominal and degraded conditions.
- Decision error count for a known training sequence.
- Explicit statement limiting the result to common-reference sample-phase
  selection.

## Done when

- [ ] Calibration selects a stable phase and plausible threshold.
- [ ] Fault/timeout behavior is explicit and tested.
- [ ] Exactly one bit-valid pulse occurs per symbol in receive mode.
- [ ] All 25 synthetic phase cases pass.
- [ ] Physical training decisions are reliable at 10 kbit/s.

## What this unlocks

Milestone 12 receives a clean bit stream with explicit validity and can focus on
frame synchronization, PRBS alignment, and trustworthy BER counters.
