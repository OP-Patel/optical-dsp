# Milestone 03 completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `03 — PRBS-15 source and checker` |
| Date completed | 2026-08-11, America/Toronto |
| Git commit | `7414fa25b61dee3245df2a3f961d655e29e7d471` plus intentional uncommitted Milestone 03 files |
| Working tree | Milestone 03 RTL, tests, protocol, scripts, and evidence are not yet committed |
| Vivado/simulator | Vivado Simulator 2026.1, build 6511674 |
| Hardware IDs | Not applicable; this milestone is simulation-only |

## What I built

- `prbs15_gen`: a deterministic, seedable PRBS-15 generator that advances only
  when `advance` is asserted and defensively recovers from the illegal zero
  state.
- `prbs15_check`: an expected-sequence generator and one-cycle mismatch pulse
  that compares and advances only when `bit_valid` is asserted.
- Independent, self-checking generator and checker testbenches.
- A frozen protocol convention and reproducible Vivado waveform capture.

The transmitter and checker share the same named generator convention, while
the generator testbench anchors correctness to a fixed external golden vector
and a complete period test.

## Design decisions I can explain

- The implementation uses polynomial `x^15 + x^14 + 1`, seed `15'h0001`,
  feedback `state[14] ^ state[13]`, insertion at `state[0]`, and current
  `state[14]` as the pre-advance output bit.
- Control priority is reset, explicit seed load, zero-state recovery, advance,
  then hold.
- The source reloads the frozen seed at each payload boundary so the checker can
  align deterministically.
- The checker intentionally omits optional counters. The final BER engine can
  wrap its `error_pulse`; the unit test uses an independent scoreboard.

The complete frozen convention and first-bit vectors are in
[`docs/protocol.md`](../../protocol.md).

## Commands run

```powershell
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat' -sv `
    rtl\common\prbs15_gen.sv rtl\common\prbs15_check.sv `
    rtl\tb\tb_prbs15_gen.sv rtl\tb\tb_prbs15_check.sv `
    rtl\tb\tb_prbs15_waveform.sv

& 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat' `
    tb_prbs15_gen -s tb_prbs15_gen_evidence
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat' `
    tb_prbs15_gen_evidence -runall

& 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat' `
    tb_prbs15_check -s tb_prbs15_check_evidence
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat' `
    tb_prbs15_check_evidence -runall
```

## Automated verification

| Test | Expected | Observed | Evidence | Pass? |
|---|---|---|---|---|
| First 64 output bits | Match frozen vector | All 64 matched | [`tb_prbs15_gen.txt`](../../evidence/milestone-03/tb_prbs15_gen.txt) | Yes |
| Full PRBS-15 period | Seed returns only after 32,767 advances | Period 32,767; zero never visited | [`tb_prbs15_gen.txt`](../../evidence/milestone-03/tb_prbs15_gen.txt) | Yes |
| Hold and control priority | State holds; reset/load priorities are deterministic | 65,610 total generator checks passed | [`tb_prbs15_gen.txt`](../../evidence/milestone-03/tb_prbs15_gen.txt) | Yes |
| Clean checker loopback | 100,000 comparisons and zero errors | 100,000 clean bits passed | [`tb_prbs15_check.txt`](../../evidence/milestone-03/tb_prbs15_check.txt) | Yes |
| Error injection | Errors only at indices 0, 17, and 999 | Exactly three errors detected | [`tb_prbs15_check.txt`](../../evidence/milestone-03/tb_prbs15_check.txt) | Yes |
| Invalid gaps and reseed | No comparison/advance during gaps; deterministic restart | 101,089 total checker checks passed | [`tb_prbs15_check.txt`](../../evidence/milestone-03/tb_prbs15_check.txt) | Yes |

The focused [waveform](../../evidence/milestone-03/prbs15_waveform.png) shows
seed load, held state, valid advances, an injected mismatch, and its one-cycle
error pulse. Its underlying
[VCD](../../evidence/milestone-03/prbs15_waveform.vcd) was captured by Vivado
Simulator.

## Hardware verification

Not applicable. These reusable sequence components were verified in simulation
before their later integration into the optical framing and BER paths.

## Problems encountered and fixes

1. The zero-recovery test initially held a forced value through the simulator's
   nonblocking update, hiding the DUT's recovery assignment. Releasing the force
   after the active-edge sample but before the NBA update made the test exercise
   the intended hardware behavior.
2. `checker` is a SystemVerilog keyword in the 2017 language revision. The
   waveform-only instance was renamed `dut_checker`.
3. Vivado waveform capture requires an elaborated debug database. The focused
   snapshot is elaborated with `-debug typical` before exporting VCD.

## What I learned

The polynomial name alone does not define a serial PRBS stream. Shift direction,
tap interpretation, feedback insertion, selected output bit, and whether the
bit is observed before or after advance must all be frozen. A maximum-length
period matters because it exposes the link to all nonzero LFSR states and varied
transition patterns before repeating, improving BER-test coverage while keeping
the expected sequence completely reproducible.

## Upgrade parking lot

- Add wide compared/error counters in the later BER engine instead of coupling
  measurement width to this small checker.
- Add synthesis attributes for physical LFSR placement only if later timing or
  upset measurements justify them.

## Exit checklist

- [x] The sequence convention is unambiguous.
- [x] The generator passes its golden-vector and full-period tests.
- [x] The checker reports exact injected errors and compared-bit counts.
- [x] Both blocks advance only on explicit valid/enable events.
- [x] The zero-state behavior is intentional and tested.

## Reviewer decision

- Status: `PASS`
- Blocking evidence or required regression: None.
- Safe next milestone: `04 — Training pattern and framer`.
