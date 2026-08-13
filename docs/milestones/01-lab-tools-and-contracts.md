# Milestone 01 — Lab, tools, and design notebook

**Time box:** 1 day
**Depends on:** Nothing
**Produces:** A reproducible environment and a hardware record that every later
milestone can reference

## Why this milestone exists

Hardware debugging becomes confusing when the board revision, Vivado version,
pin mapping, power arrangement, or test command is uncertain. This milestone
removes those variables before you write project RTL. It is not bureaucracy:
it gives you the information needed to explain exactly what you built.

## Learning goals

By the end, you should be able to explain:

- the difference between synthesis, implementation, bitstream generation, and
  device programming;
- why generated Vivado projects are build artifacts rather than source;
- which Arty connector pins will carry laser control, DAOKI diagnostic input,
  BPW34 analog input, UART, power, and ground;
- what is known from a primary source versus merely claimed by a marketplace
  listing; and
- how the terminal wrapper locates Vivado and refuses an ambiguous JTAG chain.

## Work to complete

1. Record the exact Arty model, FPGA part, PCB revision, and serial number in
   `docs/hardware/board-inventory.md`.
2. Record the installed Vivado version and install path. Do not upgrade tools in
   the middle of V1 unless there is a documented reason.
3. Run the existing terminal wrapper in dry-run mode and save the command and
   output in your completion note.
4. Connect the Arty over USB and confirm Vivado Hardware Manager or the batch
   hardware command can identify exactly one `xc7a100t` device.
5. Download or bookmark the exact Arty A7 reference manual, schematic, master
   XDC, AMD XADC guide, and Vishay BPW34 datasheet.
6. Create `docs/hardware/prototype-wiring.md` with an initially empty pin table.
   Reserve roles, not arbitrary package pins; the exact pins are frozen when
   constraints are written.
7. Make a safe physical test area: short path, matte beam stop, no reflective
   objects, and no beam at eye level.
8. Inspect the DAOKI and BPW34-style parts when they arrive. Photograph both
   sides, label each item with a local ID, and record visible markings.

Suggested inventory fields:

| Field | Example of what belongs there |
|---|---|
| `hardware_id` | `tx_daoki_01`, `pd_bpw34_03` |
| Seller/listing | URL and order date |
| Printed markings | Exact text, not an interpretation |
| Claimed voltage/wavelength | Listing value clearly marked “unverified” |
| Measured pinout/current | Filled only after measurement |
| Photo path | Repository-relative path to a selected small image |
| Notes | Damage, lens alignment, inconsistent boards, etc. |

## SystemVerilog context for the next milestone

No permanent project RTL is required here. Before moving on, review these rules:

- `logic` is the normal signal type in SystemVerilog RTL.
- Sequential state belongs in `always_ff @(posedge clk)` and uses nonblocking
  assignments (`<=`).
- Pure combinational decisions belong in `always_comb` and must assign every
  output on every path.
- Use the 100 MHz board clock as the main clock. Create one-cycle enable pulses,
  not slower clocks in LUT fabric.
- Constrain every top-level port and declare its I/O standard.
- A testbench should end with `$finish` on success and `$fatal` on failure.

Write these principles in your own words in the milestone completion note.

## Verification

There is no RTL testbench yet. Verification is procedural and must be captured:

- `git status` shows only intentional source/document changes.
- `scripts/fpga.cmd ... -DryRun` resolves the intended paths without opening the
  GUI or touching hardware.
- The connected hardware query reports exactly the expected FPGA part.
- Every selected source link opens and identifies the correct board/component.
- Your wiring table names the signal roles and voltage domains.
- The laser safety setup is photographed with the laser off.

## Completion evidence

Create `docs/milestones/completions/01-lab-tools.md` containing:

- date, Git commit, Windows version, and Vivado version;
- exact commands run and summarized results;
- FPGA part and board revision;
- links to the hardware inventory and wiring table;
- one paragraph explaining the Vivado flow in your own words; and
- open questions that must be answered before powering the optical hardware.

## Done when

- [x] The toolchain is reproducible from a VS Code terminal.
- [x] The correct FPGA is visible over JTAG.
- [x] Primary hardware sources and local device IDs are recorded.
- [x] The safe optical workspace and beam stop exist.
- [x] No unresolved board-model or voltage-domain ambiguity remains.

## Scope guard

Do not create the DSP pipeline, Vivado block design, XADC logic, or GUI here.
The purpose is to eliminate environmental ambiguity, not to get ahead.

## What this unlocks

Milestone 02 can build permanent reset and clock-enable components against a
known 100 MHz board and verified terminal flow.
