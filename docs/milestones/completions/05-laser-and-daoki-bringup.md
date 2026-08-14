# Milestone 05 completion evidence

## Identity

| Field | Value |
|---|---|
| Milestone | `05 — Laser transmitter and DAOKI digital bring-up` |
| Date prepared | 2026-08-13, America/Toronto |
| Git commit | `958be2c4e748ce43d9b26a80d551c26ba153ff27` plus intentional uncommitted Milestone 05 work |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware status | `PASS` - physical KY-008 transmitter functional test completed by the project owner on 2026-08-13 |

## What I built

- A combinational `laser_output_guard` that forces OFF during reset or disable.
- A constrained 1 kbit/s `optical_tx_bringup_top` integrating reset,
  synchronized switches, symbol enable, framer, output guard, and DAOKI
  diagnostic synchronizer.
- A reusable two-flop `async_input_sync` for the digital receiver input.
- Unit and integration testbenches plus a reproducible routed bitstream build.

SW0 disables the physical output immediately. Enabling waits for two clock
stages. SW1/SW2 are synchronized before selecting mode, preventing asynchronous
mechanical inputs from directly entering the framer FSM.

## Pin and control contract

| Board point | RTL signal | Purpose |
|---|---|---|
| SW0 / A8 | `tx_enable` | Independent final-output permission |
| SW1 / C11 | `mode[0]` | Mode least-significant bit |
| SW2 / C10 | `mode[1]` | Mode most-significant bit |
| LD5 / J5 | `fault` | Blocked ON-request indicator |
| JA4 / D12 | `laser_drive` | KY-008 `S` control |
| JA1 / G13 | `daoki_rx_async` | Measured-safe diagnostic receiver input |
| LD6 / T9 | `daoki_rx_led` | Synchronized diagnostic receiver state |

Modes use `{SW2, SW1}`: `00=OFF`, `01=ON`, `10=TRAINING`, and
`11=FRAMED`.

## Automated verification

| Test | Observed | Evidence | Pass? |
|---|---|---|---|
| Guard truth table | 27 checks, all 8 combinations | [`tb_laser_output_guard.txt`](../../evidence/milestone-05/tb_laser_output_guard.txt) | Yes |
| Diagnostic synchronizer | 7 reset/latency/edge checks | [`tb_async_input_sync.txt`](../../evidence/milestone-05/tb_async_input_sync.txt) | Yes |
| Top integration | 233 switch/mode/reset/framer/diagnostic checks | [`tb_optical_tx_bringup_top.txt`](../../evidence/milestone-05/tb_optical_tx_bringup_top.txt) | Yes |
| Routed timing | WNS `+5.978 ns`, WHS `+0.183 ns` | `artifacts/reports/milestone-05-timing-summary.rpt` | Yes |
| Bitstream DRC | Zero errors | `artifacts/logs/20260812-230319-build.log` | Yes |

## Prepared bitstream

```text
artifacts/bitstreams/optical_tx_bringup_top.bit
SHA-256 B57D7D96881556E4AD815156586618C8606C43A20394651839483C649D1A34C3
```

The prepared bitstream was programmed onto the FPGA. The project owner reported
that the physical KY-008 transmitter test passed with `S` connected to JA4,
`-` connected to JA5 ground, and the middle module pin left unconnected.

## Physical transmitter verification

| Test | Observed result | Pass? |
|---|---|---|
| FPGA programming and optical transmitter operation | KY-008 responded to the programmed FPGA output using the documented two-wire connection | Yes |
| Delivered-module pinout | `S` to JA4, `-` to JA5 ground, middle pin unconnected | Yes |

This is a user-observed functional pass. Loaded JA4 voltage/current, supply
measurements, annotated photos, and DAOKI receiver tests have not been recorded,
so this report does not invent or imply those measurements.

## Commands run

```powershell
& 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat' -sv `
    rtl\common\reset_sync.sv rtl\common\clock_enable_gen.sv `
    rtl\common\async_input_sync.sv rtl\common\prbs15_gen.sv `
    rtl\tx\optical_framer.sv rtl\tx\laser_output_guard.sv `
    rtl\top\optical_tx_bringup_top.sv `
    rtl\tb\tb_laser_output_guard.sv rtl\tb\tb_async_input_sync.sv `
    rtl\tb\tb_optical_tx_bringup_top.sv

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\fpga.ps1 `
    build -BuildScript scripts\build_optical_tx_bringup.tcl `
    -VivadoPath C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
```

## Follow-up evidence still required

- [ ] Record annotated wiring photos and module IDs.
- [ ] Record the already-working KY-008's loaded `S` voltage and GPIO current.
- [ ] Measure module OFF/ON supply current and voltage.
- [x] Program the FPGA and confirm that the KY-008 operates from JA4.
- [x] Confirm the physical pinout: `S` to JA4, `-` to JA5, middle pin unconnected.
- [ ] Record separate physical observations for reset, SW0 disable, and mode `00`.
- [ ] Record separate physical observations for OFF, ON, TRAINING, and FRAMED at 1 kbit/s.
- [ ] Measure raw DAOKI receiver dark/illuminated voltages before JA1 connection.
- [ ] Verify LD6 follows the safely translated receiver output.
- [ ] Record the highest reliable DAOKI diagnostic rate.

## Reviewer decision

- Status: `PHYSICAL TRANSMITTER FUNCTIONAL TEST PASS — ELECTRICAL AND RECEIVER EVIDENCE PENDING`
- RTL/build blocker: None.
- Safe next action: Record the remaining electrical measurements and DAOKI
  receiver evidence without changing the confirmed KY-008 wiring.
- Safe next milestone: Milestone 06 only after this report's hardware items are
  recorded and the Milestone 05 exit checklist is complete.
