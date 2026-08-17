# Milestone 07 completion report

## Identity

| Field | Value |
|---|---|
| Milestone | `07 — Capture buffer and UART evidence path` |
| Date completed | 2026-08-17, America/Toronto |
| Vivado/simulator | Vivado and Vivado Simulator 2026.1, build 6511674 |
| Hardware status | `PASS` — grounded and nominal-3.3 V captures decoded and saved |

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

## Physical verification

The board was allowed to initialize and BTN0 was pressed once to clear the
startup XADC status before each measurement. Both packets passed CRC because the
host utility saves a CSV only after successful protocol decoding.

| Input | Samples | Index range | Minimum | Maximum | Mean | CSV SHA-256 |
|---|---:|---:|---:|---:|---:|---|
| A0 connected to board ground | 1,024 | 734452–735475 | 11 | 16 | 13.2988 | `BCEAF3CF32A2BA3EA0FD6C489B34B1A7423EA49EDD49096C40FF858295FE8EC4` |
| A0 connected to nominal board 3V3 | 1,024 | 6267218–6268241 | 4067 | 4074 | 4070.5381 | `05739C72C1719DD3CC0F5C481424092FFE87BAE982B16F7106FAD080D0E9516B` |

Evidence files:

- `artifacts/captures/a0-ground.csv`
- `artifacts/captures/a0-3v3.csv`

The response is monotonic and spans 99.08% of the ideal 12-bit range after
subtracting the measured ground offset. The 3V3 rail was used as a nominal
functional endpoint and was not independently measured, so this is not a
precision voltage calibration.

## Reviewer decision

- Status: `PASS`
- RTL/build blocker: None.
- Follow-up carried by Milestone 8: screen the passive, board-3V3-bounded BPW34
  receiver for clipping, separation, transition speed, and repeatability.
