# Optical analog-front-end selection record

This is the Milestone 08 freeze record. `pd02` was selected on 2026-08-19 from
repeatable saved CSV/JSON evidence. Rate acceptance passed; rebuild-from-scratch
realignment remains pending.

## Hardware identity

| Item | Selected value |
|---|---|
| Arty board ID | Arty A7-100T; local serial/asset ID not recorded |
| KY-008 transmitter ID | Working two-wire unit from Milestone 05; local ID not recorded |
| Selected photodiode ID | `pd02` |
| Verified cathode marking/orientation | Cathode to Arty 3V3; positive response under illumination |
| External load resistance | 100 kΩ |
| Effective load note | Dominated by the Arty A0 onboard 2.32 kΩ/1 kΩ divider |
| FPGA bitstream SHA-256 | `BBE292C9EF3247229BE6376956ECA750D4E5B59ABAFE441C1F301935FD252BCD` |

## Frozen wiring and geometry

| Item | Value |
|---|---|
| Bias source | Arty 3V3 |
| Sense input | Arty A0 / VAUX4 |
| Distance | 7.4 cm between the mounted transmitter and detector |
| Mechanical mounting | Transmitter and detector fixed approximately 2 cm above the supporting surface |
| Nominal alignment method | Direct face-to-face line of sight at the recorded distance and height |
| Degraded condition | Beam physically blocked without moving the fixed transmitter or detector |
| Beam stop | Not recorded; retain as a safety/reproduction follow-up |
| Ambient-light policy | Stable room conditions used for all saved captures; exact lighting not recorded |

## Detector screening

| Detector | Dark mean/std | Ambient mean/std | OFF mean/std | ON mean/std | Separation | Quality | 1 kbit/s edges | Evidence | Decision |
|---|---|---|---|---|---:|---:|---|---|---|
| pd01 | Not captured | Not captured | 13.576/1.094 | 15.806/1.057 | 2.229 | 1.465 | Pending | `pd01_r100000ohm_*_run01` | Rejected in favor of pd02 |
| pd02 | Not captured | Not captured | 13.660/0.969 | 16.086/0.970 | 2.425 | 1.769 | PASS; ten fitted alternating captures | Forty-one saved CSV/JSON pairs | Selected; ten DC pairs, ten runs at each rate, one blocked run |
| pd03 | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | None | Not screened by operator decision |
| pd04 | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | None | Not screened by operator decision |
| pd05 | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | None | Not screened by operator decision |

For `pd02`, every paired run produced positive separation. The paired range was
2.054 through 2.652 codes. All packets passed CRC and all captures contained
1,024 consecutive sample indices. One code-26 sample occurred in OFF run 2 and
one code-23 sample occurred in ON run 1; neither represents rail clipping.

## 1 kbit/s training evidence

Ten `pd02` training captures were fitted against the expected alternating
1 kbit/s pattern at the nominal 240,384.615 sample/s rate. Each capture held
1,024 consecutive samples and passed packet CRC.

| Result | Observed |
|---|---:|
| Captures | 10 |
| Expected samples/symbol | 240.385 |
| Mean fitted low/high separation | 2.527 codes |
| Minimum fitted separation | 2.383 codes |
| Maximum fitted separation | 2.637 codes |
| Clipped samples | 0 |

The fitted training separation agrees with the 2.425-code aggregate DC
separation. Raw sample-by-sample threshold crossings are noise-sensitive at
this small amplitude, so transition timing is not claimed from the unsmoothed
crossing count.

## 10 kbit/s training evidence

All ten 10 kbit/s captures passed CRC and contained 1,024 consecutive samples
with no clipping. Fitting the expected alternating pattern produced:

| Result | Observed |
|---|---:|
| Captures | 10 |
| Expected samples/symbol | 24.038 |
| Expected transitions in capture | Approximately 42.6 |
| Fitted transitions | 42 or 43 in every capture |
| Mean fitted separation | 2.390 codes |
| Minimum/maximum fitted separation | 2.311 / 2.488 codes |
| Mean residual standard deviation | 1.023 codes |
| Mean fitted quality | 2.339 |

Evidence: the ten
`pd02_r100000ohm_training_10000bps_run01..10.csv` files and their JSON
sidecars. Run 1 CSV SHA-256 is
`EAF1391219B347ACC6C1C59AC78258677B14AA79F53F9C6FA2A808D8B80F588D`.
The stationary 10 kbit/s rate check passes; rebuild-from-scratch realignment
repeatability remains pending.

## Blocked-path evidence

With the transmitter still sending 10 kbit/s training, physically blocking the
beam returned the capture mean to 13.682 codes and reduced the best fitted
alternating separation to 0.176 codes. The nominal ten-run separation was
2.390 codes, so blocking reduced it by 92.6%.

| Result | Nominal | Blocked |
|---|---:|---:|
| Fitted separation | 2.390 codes | 0.176 codes |
| Fit quality | 2.339 | 0.177 |
| Sample range | 10–24 across ten runs | 11–17 |
| Packet/sample integrity | PASS | PASS |

Blocked evidence:
`pd02_r100000ohm_blocked_10000bps_run01.csv`, SHA-256
`7B7AE92693E5A4BFA773D29FD342604D4C45AB4E7CF4B5462C469C8DAB3BA954`.
This confirms that the recovered periodic signal traveled through the optical
path rather than arising from electrical coupling inside the FPGA setup.

## Resistor and rate sweep

| Detector | Resistance | OFF mean/std | ON mean/std | Separation | Quality | 1 kbit/s pattern | 10 kbit/s pattern | Clipping | Evidence |
|---|---:|---|---|---:|---:|---|---|---|---|
| pd01 | 1 kΩ | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Onboard A0 divider makes this lower value unhelpful |
| pd01 | 2 kΩ | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Not tested | Onboard A0 divider makes this lower value unhelpful |
| pd01 | 10 kΩ | 13.577/0.992 | 15.537/1.005 | 1.960 | 1.388 | Pending | Pending | No | `pd01_r10000ohm_*_run01` |
| pd01 | 100 kΩ | 13.576/1.094 | 15.806/1.057 | 2.229 | 1.465 | Pending | Pending | No | `pd01_r100000ohm_*_run01` |
| pd02 | 100 kΩ | 13.660/0.969 | 16.086/0.970 | 2.425 | 1.769 | PASS; fitted separation 2.527 | PASS; ten runs, separation 2.390 | No | Ten DC pairs and ten runs at each training rate |

The 1 kΩ and 2 kΩ values remain recorded as deliberately untested because the
onboard A0 divider makes them counterproductive for this passive circuit.

## Three-run realignment repeatability

| Run | OFF mean/std | ON mean/std | Separation | 10 kbit/s rise/fall | Degraded result | Evidence |
|---:|---|---|---:|---|---|---|
| 1 | Pending | Pending | Pending | Pending | Pending | Pending |
| 2 | Pending | Pending | Pending | Pending | Pending | Pending |
| 3 | Pending | Pending | Pending | Pending | Pending | Pending |

The rebuild-from-scratch three-run realignment procedure was not performed due
to session limits. Milestone 08 closes with this as an explicit follow-up. Ten
stationary OFF/ON pairs, ten training captures at each rate, and one blocked
10 kbit/s capture support the selected fixed setup, but they do not replace a
future mechanical rebuild test.

## Final selection

| Question | Answer |
|---|---|
| Why this detector? | Ten paired runs all had positive separation and the aggregate result was stronger than pd01 |
| Why this resistance? | It minimally loads the approximately 3.32 kΩ A0 input path; smaller available resistors reduce signal |
| Minimum/maximum observed code | 10/26 across the twenty pd02 OFF/ON captures |
| Nominal ON/OFF separation | 2.425 codes aggregate; paired range 2.054–2.652 |
| Pooled noise and simple quality | Approximate average pooled noise 1.371 codes; quality 1.769 |
| 1 kbit/s training result | PASS; all ten captures fit the alternating pattern, mean separation 2.527 codes |
| 10 kbit/s transition margin | PASS; all ten captures had 42–43 expected-pattern transitions, mean separation 2.390 codes |
| Blocked-path result | PASS; fitted separation reduced by 92.6% and mean returned to OFF level |
| Main limitation | Absolute DC separation is small; rebuild-from-scratch realignment repeatability remains pending |
| Trigger that would justify a future TIA | Passive configurations fail documented 1 kbit/s separation or 10 kbit/s transition requirements |

## Milestone decision

`PASS WITH FOLLOW-UP` on 2026-08-19, America/Toronto. The selected V1 receiver
is `pd02`, 100 kΩ external load, 7.4 cm optical distance, and approximately
2 cm mounting height. Both 1 and 10 kbit/s training passed repeated stationary
captures, and blocking the optical path removed 92.6% of the fitted pattern.
Formal rebuild-from-scratch realignment and a more precise ambient/mechanical
record remain follow-up work.

## Evidence integrity

Every accepted row must link to the automatically generated capture JSON, CSV,
and SHA-256. Record failed or clipped configurations rather than deleting them.
