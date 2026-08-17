# Milestone 07 automated evidence

Prepared on 2026-08-15 with Vivado and Vivado Simulator 2026.1.

## Focused RTL simulations

| Testbench | Result | Main coverage |
|---|---|---|
| `tb_crc16_ccitt` | PASS, 4 checks | Reset/clear and published `123456789 -> 29B1` vector |
| `tb_uart_tx` | PASS, 426 checks | Exact bit timing, six decoded bytes, held-valid traffic, reset during byte |
| `tb_sample_capture` | PASS, 25 checks | Valid-only writes, ordering, metadata, rejection, synchronous read, reset |
| `tb_packet_tx` | PASS, 58 checks | Zero/ordinary/maximum payloads, backpressure, exact CRC, oversize rejection |
| `tb_capture_streamer` | PASS, 53 checks | RAM latency and exact 29-byte RTL/Python capture fixture |

The individual xsim transcripts are stored beside this README. The complete HDL
regression also passed all 11 earlier Milestone 2–6 testbenches, for 16 passing
HDL testbenches total.

## Python tests

`python -m unittest discover -s host/tests -v` passed all 7 tests. The transcript
is `python-tests.txt`. It covers CRC rejection, framing, fragmented reads, noise
resynchronization, capture payload validation, and the shared RTL fixture.

## Routed FPGA build

| Check | Result |
|---|---|
| Top | `capture_uart_bringup_top` |
| Device | `xc7a100tcsg324-1` |
| Setup timing | WNS `+3.760 ns`, 0 failing endpoints |
| Hold timing | WHS `+0.119 ns`, 0 failing endpoints |
| DRC | 0 checks |
| Utilization | 316 LUTs, 501 registers, one RAMB18E1, one XADC |
| Bitstream | `artifacts/bitstreams/capture_uart_bringup_top.bit` |
| SHA-256 | `A89E416A1DF8EE9CB2C627AA5A549F76E780CD9E73AB6B120A1BF20802D6146E` |
| Final build log | `artifacts/logs/20260815-000253-build.log` |

Vivado 2026.1 failed internally in its optional block-RAM power-optimization
pass. The build uses the documented `RuntimeOptimized` logic-optimization
directive, which retains standard cleanup and omits that optional pass. The
result then completed placement, routing, timing analysis, DRC, and bitstream
generation successfully.

## Physical verification

Physical verification passed on 2026-08-17. The host decoder accepted and saved
both CRC-protected packets with exactly 1,024 consecutive sample indices.

| Input | Start index | Minimum | Maximum | Mean | Evidence |
|---|---:|---:|---:|---:|---|
| Board ground | 734452 | 11 | 16 | 13.2988 | `artifacts/captures/a0-ground.csv` |
| Nominal board 3V3 | 6267218 | 4067 | 4074 | 4070.5381 | `artifacts/captures/a0-3v3.csv` |

The grounded file SHA-256 is
`BCEAF3CF32A2BA3EA0FD6C489B34B1A7423EA49EDD49096C40FF858295FE8EC4`.
The nominal-3V3 file SHA-256 is
`05739C72C1719DD3CC0F5C481424092FFE87BAE982B16F7106FAD080D0E9516B`.

LD7 remained clear after the deliberate post-configuration BTN0 reset. The
nominal board rail was not independently measured, so the result is a functional
endpoint check rather than precision voltage calibration.
