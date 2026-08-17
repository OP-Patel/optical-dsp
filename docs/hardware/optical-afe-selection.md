# Optical analog-front-end selection record

This is the Milestone 08 freeze record. Keep `Pending` until supported by saved
CSV/JSON evidence; do not select a configuration from appearance alone.

## Hardware identity

| Item | Selected value |
|---|---|
| Arty board ID | Pending |
| KY-008 transmitter ID | Pending |
| Selected photodiode ID | Pending |
| Verified cathode marking/orientation | Pending |
| Load resistance | Pending |
| FPGA bitstream SHA-256 | Pending |

## Frozen wiring and geometry

| Item | Value |
|---|---|
| Bias source | Arty 3V3 |
| Sense input | Arty A0 / VAUX4 |
| Distance | Pending |
| Mechanical mounting | Pending |
| Nominal alignment method | Pending |
| Degraded alignment method | Pending |
| Beam stop | Pending |
| Ambient-light policy | Pending |

## Detector screening at 10 kΩ

| Detector | Dark mean/std | Ambient mean/std | OFF mean/std | ON mean/std | Separation | Quality | 1 kbit/s edges | Evidence | Decision |
|---|---|---|---|---|---:|---:|---|---|---|
| pd01 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| pd02 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| pd03 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| pd04 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| pd05 | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Resistor and rate sweep

| Detector | Resistance | OFF mean/std | ON mean/std | Separation | Quality | 1 kbit/s rise/fall | 10 kbit/s rise/fall | Clipping | Evidence |
|---|---:|---|---|---:|---:|---|---|---|---|
| Pending | 4.7 kΩ | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Pending | 10 kΩ | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Pending | 47 kΩ | Pending | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

Values not physically available may be removed with a note rather than
inventing measurements.

## Three-run realignment repeatability

| Run | OFF mean/std | ON mean/std | Separation | 10 kbit/s rise/fall | Degraded result | Evidence |
|---:|---|---|---:|---|---|---|
| 1 | Pending | Pending | Pending | Pending | Pending | Pending |
| 2 | Pending | Pending | Pending | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending | Pending | Pending | Pending |

## Final selection

| Question | Answer |
|---|---|
| Why this detector? | Pending |
| Why this resistance? | Pending |
| Minimum/maximum observed code | Pending |
| Nominal ON/OFF separation | Pending |
| Pooled noise and simple quality | Pending |
| 10 kbit/s transition margin | Pending |
| Main limitation | Pending |
| Trigger that would justify a future TIA | Passive configurations fail documented 1 kbit/s separation or 10 kbit/s transition requirements |

## Evidence integrity

Every accepted row must link to the automatically generated capture JSON, CSV,
and SHA-256. Record failed or clipped configurations rather than deleting them.
