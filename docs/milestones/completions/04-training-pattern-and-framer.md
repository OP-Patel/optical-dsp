# Milestone 04 completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `04 — Optical training pattern and framer` |
| Date completed | 2026-08-12, America/Toronto |
| Git commit | `0002b646d3a78abdb450b439d202f1d3a5b21e3d` plus intentional uncommitted Milestone 04 files |
| Working tree | Milestone 04 RTL, tests, protocol update, scripts, and evidence are not yet committed; unrelated earlier edits were preserved |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware IDs | Not applicable; this milestone ends at logical-stream simulation and isolated synthesis |

## What I built

- `optical_framer`: a four-mode logical transmitter with constant-off,
  constant-on, alternating-training, and framed PRBS output.
- A single framing FSM that sends a 32-bit alternating preamble, 16-bit sync,
  16-bit frame sequence, and 1024-bit seeded PRBS payload.
- A self-checking functional testbench and a smaller waveform-evidence
  testbench.
- Reproducible waveform-rendering and isolated-synthesis scripts.

The mode is an output selection, not a second FSM. The one actual FSM moves
through `PREAMBLE`, `SYNC`, `SEQUENCE`, and `PAYLOAD` only on `symbol_ce`.

## Design decisions I can explain

- The sync word is frozen as `16'hD5B3`, transmitted MSB first after
  `32'hAAAAAAAA`.
- All mode changes take effect immediately. Leaving framed mode aborts the
  partial frame; re-entering starts at preamble bit zero. `OFF` therefore
  forces a safe logical zero without waiting for a frame boundary.
- The existing `prbs15_gen` is owned by the framer. It reloads once when the
  sequence field ends and advances once for each consumed payload symbol.
- Reset forces `tx_bit` low, resets the sequence to zero, initializes training
  to begin with `1`, and parks the FSM at the first preamble bit.
- Fixed fields are MSB first. The sequence increments after the last payload
  symbol, wraps naturally at 16 bits, and the PRBS payload repeats because each
  payload begins from `15'h0001`.

## Commands run

```powershell
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat' -sv `
    rtl\common\prbs15_gen.sv rtl\tx\optical_framer.sv `
    rtl\tb\tb_optical_framer.sv rtl\tb\tb_optical_framer_waveform.sv

& 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat' `
    tb_optical_framer -s tb_optical_framer_m04
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat' `
    tb_optical_framer_m04 -runall

& 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat' `
    tb_optical_framer_waveform -debug typical `
    -s tb_optical_framer_waveform_m04
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat' `
    tb_optical_framer_waveform_m04 `
    -tclbatch scripts/capture_optical_framer_waveform.tcl

python scripts\render_optical_framer_waveform.py `
    docs\evidence\milestone-04\optical_framer_waveform.vcd `
    docs\evidence\milestone-04\optical_framer_waveform.png

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\fpga.ps1 `
    build -BuildScript scripts\synth_optical_framer.tcl `
    -VivadoPath C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
```

## Automated verification

| Test | Expected | Observed | Evidence | Pass? |
|---|---|---|---|---|
| Four transmit modes | 100 correct symbols per basic mode and deterministic framed output | OFF, ON, and TRAINING each passed 100 symbols; FRAMED passed 2176 symbols | [`tb_optical_framer.txt`](../../evidence/milestone-04/tb_optical_framer.txt) | Yes |
| Frame structure | Exactly 1088 symbols with correct boundaries and MSB-first fields | Two complete frames matched bit by bit, including stalls | [`tb_optical_framer.txt`](../../evidence/milestone-04/tb_optical_framer.txt) | Yes |
| PRBS ownership | One seed load and 1024 advances per payload | Two seed loads and 2048 advances; both payloads identical | [`tb_optical_framer.txt`](../../evidence/milestone-04/tb_optical_framer.txt) | Yes |
| Sequence behavior | First two fields are zero and one; increment at frame completion | Sequence advanced from 0 to 1 to 2 at the expected boundaries | [`tb_optical_framer.txt`](../../evidence/milestone-04/tb_optical_framer.txt) | Yes |
| Enable stalls | State, index, PRBS, output, and sequence hold in every frame state | All six hold properties passed over three-clock stalls in all states | [`optical_framer_waveform.png`](../../evidence/milestone-04/optical_framer_waveform.png) | Yes |
| Mode changes and reset | Immediate documented switching; safe reset from every state | Mid-payload TRAINING/OFF and reset from all four frame states passed | [`tb_optical_framer.txt`](../../evidence/milestone-04/tb_optical_framer.txt) | Yes |
| Synthesis | FSM inferred; no latch or generated fabric clock | 42 LUTs, 46 flip-flops, zero latches, one input-clock BUFG | [`synthesis-summary.txt`](../../evidence/milestone-04/synthesis-summary.txt) | Yes |

The final transcript reports 9,521 passing checks.

## Hardware verification

Not applicable. The FPGA is connected, but Milestone 04 intentionally remains
independent of the laser pin and physical hardware. Programming it would not
provide additional evidence until Milestone 05 adds the constrained, safe
transmitter output path.

## Problems encountered and fixes

1. The first testbench compile used `sequence` as a function argument, but it
   is a SystemVerilog assertion keyword. Renaming it to `sequence_value` fixed
   compilation.
2. The first scoreboard draft inspected `tx_bit` after the consuming edge,
   when the framer had already prepared the next symbol. Capturing the emitted
   bit before that edge removed the off-by-one ambiguity.
3. Direct Vivado synthesis loaded the Windows user Tcl profile and failed on
   the space in the profile path. The repository's isolated Vivado-profile
   wrapper completed synthesis with zero tool warnings or RTL errors.

## What I learned

The mode and frame state serve different purposes. Mode chooses the source
connected to `tx_bit`; the frame FSM only tracks the current field when framed
output is selected. I can now explain exactly which bit is visible before a
`symbol_ce` edge, which registers change at that edge, and why the payload seed
load occurs on the final sequence-symbol event.

## Upgrade parking lot

- Add a pending-mode register only if later control-plane testing requires
  non-OFF changes to wait for a complete frame.
- Expose internal state or counters through telemetry only when Milestone 13
  defines the permanent status-register map.

## Exit checklist

- [x] All four modes are deterministic and safe on reset.
- [x] The frame is exactly 1088 symbols under stalls in `symbol_ce`.
- [x] PRBS control aligns exactly with payload boundaries.
- [x] Mode changes follow a documented, tested rule.
- [x] The module is independent of the laser pin and physical hardware.

## Reviewer decision

- Status: `PASS`
- Blocking evidence or required regression: None.
- Safe next milestone: `05 — Laser transmitter and DAOKI digital bring-up`.
