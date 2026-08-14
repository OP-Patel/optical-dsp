| External Pin | Arty A7 Pin | Use Case |
| --- | --- |
| KY-008 |
| Middle PIN2 | Not connected | Confirmed unused on this delivered variant |
| GND PIN3 (-) | GND - JA5  | Ground Pin | 
| SIG PIN1 (S) | JA4 | Positive supply/control (HIGH == ON); loaded voltage/current measurement pending |
| --- | --- |

Physical transmitter functional test: `PASS` on 2026-08-13. The programmed FPGA
successfully controlled the KY-008 with `S` on JA4, `-` on JA5 ground, and the
middle pin unconnected. Loaded voltage/current measurements remain pending.

| BPW34 |
| Cathode | VCC3V3 - JA12 | Power BPW34 (less than 60V max) |
| Anode | GND - JA11 | Ground Pin | 
| --- | --- |
