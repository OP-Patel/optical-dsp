# Milestone 07 partial completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `07 — Capture buffer and UART evidence path` |
| Date prepared | 2026-08-15, America/Toronto |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware status | Routed bitstream ready; physical UART/A0 captures pending |

## What was implemented

- A 1,024-entry, 12-bit capture buffer inferred as one RAMB18E1.
- Arm, trigger, full-rate capture, frozen readback, start-index metadata, and
  visible rejected-control status.
- A reusable ready/valid packet encoder with CRC-16/CCITT-FALSE.
- A 115200-baud UART transmitter using 868 system clocks per serial bit.
- A capture streamer that handles synchronous block-RAM read latency.
- An integrated XADC/capture/UART top, constraints, and routed build script.
- A reusable Python packet decoder, serial transport, and CSV capture command.
- Five focused RTL testbenches plus seven Python protocol tests.

## Frozen interfaces

The UART uses 115200 8N1 and sends data LSB-first. The actual integer-divider
baud is 115207.373 baud, an error of +0.0064%.

Packets use sync `A5 5A`, version `01`, little-endian length and sequence, a
maximum 4,096-byte payload, and a little-endian CRC. CRC covers version through
payload, uses polynomial `0x1021`, initial value `0xFFFF`, no reflection, and no
final XOR.

Capture type `02` contains a 64-bit starting sample index, 16-bit count, format
`01`, and one little-endian 16-bit field per unsigned 12-bit sample.

## Automated results

| Check | Observed | Pass? |
|---|---|---|
| Milestone 7 RTL tests | 5 testbenches, 566 explicit checks | Yes |
| Full HDL regression | 16 testbenches including Milestones 2–6 | Yes |
| Python tests | 7 tests including shared RTL fixture and corrupt-CRC rejection | Yes |
| Block-RAM inference | One RAMB18E1; no distributed capture registers | Yes |
| Routed timing | WNS `+3.760 ns`, WHS `+0.119 ns`, zero failing endpoints | Yes |
| DRC | Zero checks | Yes |
| Bitstream generation | Completed successfully | Yes |

## Prepared bitstream

```text
artifacts/bitstreams/capture_uart_bringup_top.bit
SHA-256 A89E416A1DF8EE9CB2C627AA5A549F76E780CD9E73AB6B120A1BF20802D6146E
```

Build and program it with:

```powershell
.\scripts\fpga.cmd build `
    -BuildScript scripts\build_capture_uart_bringup.tcl

.\scripts\fpga.cmd program `
    -Bitstream artifacts\bitstreams\capture_uart_bringup_top.bit
```

Receive one physical capture with:

```powershell
$env:PYTHONPATH = "host"
python -m pip install pyserial
python host\capture_samples.py COM5 --output artifacts\captures\a0-ground.csv
```

Replace `COM5` with the Arty USB-UART port, start the receiver, press BTN1 to
arm, and then press BTN2 to trigger.

## Reviewer decision

- Status: `RTL / SIMULATION / ROUTED BUILD PASS — PHYSICAL CAPTURE PENDING`
- RTL/build blocker: None.
- Remaining evidence: grounded and known-level A0 capture packets/CSVs.
