# Milestone 05 pre-hardware evidence

The RTL, simulation, constraints, implementation, and bitstream steps are
complete. Physical wiring and optical measurements have intentionally not been
performed yet.

## Simulation

| Test | Result |
|---|---|
| `tb_laser_output_guard` | `PASS`, 27 checks over all 8 reset/enable/bit combinations plus asynchronous input changes |
| `tb_async_input_sync` | `PASS`, 7 checks covering two-stage propagation and reset |
| `tb_optical_tx_bringup_top` | `PASS`, 233 integration checks across switch synchronization, all modes, enable suppression, reset, framed preamble, and DAOKI diagnostic input |

Transcripts:

- [`tb_laser_output_guard.txt`](tb_laser_output_guard.txt)
- [`tb_async_input_sync.txt`](tb_async_input_sync.txt)
- [`tb_optical_tx_bringup_top.txt`](tb_optical_tx_bringup_top.txt)

## Constrained build

Top: `optical_tx_bringup_top`  
Part: `xc7a100tcsg324-1`  
Symbol rate: 1 kbit/s (`100 MHz / 100000`)  
Bitstream: `artifacts/bitstreams/optical_tx_bringup_top.bit`  
SHA-256: `B57D7D96881556E4AD815156586618C8606C43A20394651839483C649D1A34C3`

| Check | Result |
|---|---|
| Setup timing | WNS `+5.978 ns`, no failing endpoints |
| Hold timing | WHS `+0.183 ns`, no failing endpoints |
| Routing | No failed, unrouted, or partially routed nets |
| Bitstream DRC | Zero errors |
| Utilization | 60 LUTs, 74 flip-flops, 0 latches |

Generated reports:

- `artifacts/logs/20260812-230319-build.log`
- `artifacts/reports/milestone-05-utilization.rpt`
- `artifacts/reports/milestone-05-timing-summary.rpt`
- `artifacts/reports/milestone-05-drc.rpt`

## Physical work still required

Do not connect the DAOKI receiver output to JA1 until its high voltage has been
measured or safely translated to no more than 3.3 V.

- Measure the working KY-008's loaded `S` voltage/current against the FPGA
  output-drive limit.
- Photograph and verify `S`, unused middle, and `-` markings.
- Program the prepared bitstream only with SW0 low and mode `00`.
- Verify JA4 low during reset, disable, and OFF before attaching the KY-008.
- Record OFF/ON current and voltage, then test TRAINING and FRAMED at 1 kbit/s.
- Measure DAOKI receiver dark/illuminated output voltage before JA1 connection.
- Record the highest reliable diagnostic receiver rate and optical limitations.
