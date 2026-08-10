# Milestone completion report template

Copy this file to `docs/milestones/completions/NN-short-name.md`. Keep the report
concise, but retain enough evidence for you—or a reviewer—to reproduce the
result and decide whether the next milestone is safe to start.

## Identity

| Field | Value |
|---|---|
| Milestone | `NN — name` |
| Date completed | UTC/local date |
| Git commit | Full commit hash |
| Working tree | Clean, or list intentional uncommitted files |
| Vivado/simulator | Version and edition |
| Hardware IDs | Board, TX, detector, resistor/front-end IDs used |

## What I built

Describe the new permanent modules/tools and their interfaces in your own words.
Include a small block diagram or state diagram when it helps.

## Design decisions I can explain

- Decision:
  - Alternatives considered:
  - Why this choice is understandable and sufficient for V1:
- Numeric/interface contract:
- Reset, valid, latency, rounding, saturation, or fault behavior:

## Commands run

```text
Exact simulation, build, program, and host commands
```

## Automated verification

| Test | Expected | Observed | Evidence path | Pass? |
|---|---|---|---|---|
| Unit/integration test | | | | |

Record test counts and exact injected failures where applicable. “Waveform
looked correct” is supporting evidence, not the only pass criterion.

## Hardware verification

| Configuration/condition | Measurement | Result | Evidence path |
|---|---|---|---|
| | | | |

Write `Not applicable` for simulation-only milestones rather than deleting the
section.

## Problems encountered and fixes

For each meaningful problem:

1. Symptom and failing test.
2. Root cause.
3. Fix.
4. Regression added so it cannot silently return.

## What I learned

Explain the most important concept without copying comments or the milestone
guide. Include one thing you could now explain at a whiteboard.

## Review request

List what you want reviewed before continuing, such as:

- interface clarity;
- SystemVerilog correctness or synthesis implications;
- testbench independence and missing corner cases;
- fixed-point range/rounding;
- electrical safety and measured limits; or
- whether the completion evidence supports the claim.

## Upgrade parking lot

Record attractive improvements without implementing them now. State the
measurement or completed V1 result that would justify each upgrade.

## Exit checklist

Copy the milestone's `Done when` checklist here and mark each item. Any unchecked
item is either a blocker or an explicitly reviewed exception.

## Reviewer decision

- Status: `PASS`, `PASS WITH FOLLOW-UP`, or `BLOCKED`
- Blocking evidence or required regression:
- Safe next milestone:
