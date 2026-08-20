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
| Load resistor | Sense node to Arty GND | Selected external value: 100 kΩ |
| Grounds | Arty/KY-008/resistor common | One reference for transmitter and receiver |

```text
3V3 -------- cathode BPW34 anode ----+---- A0
                                     |
                                  100 kΩ
                                     |
GND ---------------------------------+
```

Milestone 08 selected `pd02`. The transmitter and detector are separated by
7.4 cm and mounted approximately 2 cm above the supporting surface in direct
line of sight. The official Arty A0 2.32 kΩ/1 kΩ input divider dominates the
effective load, so the external 100 kΩ resistor only minimally loads it.

Illumination produced a repeatable positive sense-code change, confirming the
recorded polarity. Never substitute 5V or VU for the 3V3 bias.
