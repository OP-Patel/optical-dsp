# Milestone 05 partial completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `05 — Laser transmitter and DAOKI digital bring-up` |
| Date prepared | 2026-08-12, America/Toronto |
| Git commit | `958be2c4e748ce43d9b26a80d551c26ba153ff27` plus intentional uncommitted Milestone 05 work |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware status | FPGA connected, but no wiring/programming/optical test performed in this report |

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

The bitstream was generated but deliberately not programmed.

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

## Hardware verification still required

- [ ] Record annotated wiring photos and module IDs.
- [ ] Measure KY-008 `S` voltage/current before GPIO connection.
- [ ] Measure module OFF/ON supply current and voltage.
- [ ] Verify reset, SW0 disable, and mode `00` produce a low JA4 output.
- [ ] Verify OFF, ON, TRAINING, and FRAMED optically at 1 kbit/s.
- [ ] Measure raw DAOKI receiver dark/illuminated voltages before JA1 connection.
- [ ] Verify LD6 follows the safely translated receiver output.
- [ ] Record the highest reliable DAOKI diagnostic rate.

## Reviewer decision

- Status: `IN PROGRESS — AWAITING PHYSICAL TEST`
- RTL/build blocker: None.
- Safe next action: Complete the measured wiring and physical sequence above.
- Safe next milestone: Milestone 06 only after this report's hardware items are
  recorded and the Milestone 05 exit checklist is complete.
