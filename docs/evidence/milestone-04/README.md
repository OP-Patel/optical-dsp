# Milestone 04 evidence

## Automated simulation

[`tb_optical_framer.txt`](tb_optical_framer.txt) is the Vivado Simulator
transcript for the self-checking framer testbench. It reports:

```text
PASS: tb_optical_framer checks=9521 frames=2 seed_loads=2 prbs_advances=2048
```

The test covers 100 symbols in each constant/training mode, two complete
1088-symbol frames, exact fixed-field order, the frozen PRBS vector, identical
reseeded payloads, sequence increment, stalls in all four frame states,
immediate mode changes, and reset from every frame state.

## Waveform

[`optical_framer_waveform.png`](optical_framer_waveform.png) is rendered from
the Vivado-generated [`optical_framer_waveform.vcd`](optical_framer_waveform.vcd).
It shows the `PREAMBLE`, `SYNC`, `SEQUENCE`, and `PAYLOAD` transitions, the
one-cycle field events, PRBS controls, and a three-clock `symbol_ce` stall.
[`waveform_capture.txt`](waveform_capture.txt) records the capture command.

## Synthesis

The isolated `optical_framer` synthesis completed with zero errors, warnings,
or critical warnings. Vivado inferred the four-state FSM. The synthesized
design uses 42 LUTs and 46 flip-flops; the utilization report explicitly lists
zero latches. Its single BUFG is driven by the module's `clk` input, so the RTL
contains no fabric-generated clock.

Generated synthesis evidence:

- [`synthesis-summary.txt`](synthesis-summary.txt)
- `artifacts/logs/20260812-203029-build.log`
- `artifacts/reports/milestone-04-utilization.rpt`
- `artifacts/reports/milestone-04-timing-summary.rpt`
- `artifacts/reports/milestone-04-drc.rpt`
- `artifacts/reports/milestone-04-synth.dcp`

The isolated-module DRC report contains expected missing-pin and I/O-standard
notices because this milestone deliberately does not connect the logical
framer ports to board pins. Physical pin integration belongs to Milestone 05.
