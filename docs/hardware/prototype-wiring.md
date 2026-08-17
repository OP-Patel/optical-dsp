# Prototype wiring record

## KY-008 transmitter

| External pin | Arty connection | Use |
|---|---|---|
| SIG PIN1 (`S`) | JA4 | FPGA laser control, HIGH = ON |
| Middle PIN2 | Unconnected | Confirmed unused on the delivered variant |
| GND PIN3 (`-`) | JA5 / GND | Common ground |

Physical transmitter functional test: `PASS` on 2026-08-13. The programmed FPGA
successfully controlled the KY-008 with `S` on JA4, `-` on JA5 ground, and the
middle pin unconnected. Loaded voltage/current measurements remain pending.

## BPW34 passive receiver for Milestone 08

| Point | Connection | Use |
|---|---|---|
| BPW34 cathode | Arty 3V3, provisionally JA12 | Reverse-bias supply |
| BPW34 anode | Sense node | Photocurrent output; not connected directly to ground |
| Sense node | Arty A0 | XADC measurement input |
| Load resistor | Sense node to Arty GND | Start with 10 kΩ |
| Grounds | Arty/KY-008/resistor common | One reference for transmitter and receiver |

```text
3V3 -------- cathode BPW34 anode ----+---- A0
                                     |
                                   10 kΩ
                                     |
GND ---------------------------------+
```

The five purchased detectors must be assigned local IDs `pd01` through `pd05`.
Their orientation is not frozen until Milestone 08 measurements confirm that
the sense voltage rises under illumination. Never substitute 5V or VU for the
3V3 bias.
