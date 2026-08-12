"""Render the focused PRBS VCD evidence as a readable PNG."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SIGNALS = [
    ("clk", "clk", False),
    ("rst", "rst", False),
    ("load_seed", "load_seed", False),
    ("bit_valid / advance", "bit_valid", False),
    ("corrupt_bit", "corrupt_bit", False),
    ("bit_in", "bit_in", False),
    ("error_pulse", "error_pulse", False),
    ("source_state", "source_state", True),
    ("expected_state", "expected_state", True),
]


def read_vcd(path: Path):
    scopes: list[str] = []
    codes: dict[str, tuple[str, int]] = {}
    changes: dict[str, list[tuple[int, str]]] = {}
    now = 0

    with path.open(encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if line.startswith("$scope"):
                scopes.append(line.split()[2])
            elif line.startswith("$upscope"):
                scopes.pop()
            elif line.startswith("$var"):
                parts = line.split()
                width, code, name = int(parts[2]), parts[3], parts[4]
                full_name = ".".join([*scopes, name])
                codes[code] = (full_name, width)
                changes.setdefault(full_name, [])
            elif line.startswith("#"):
                now = int(line[1:])
            elif line and line[0] in "01xXzZ":
                code = line[1:]
                if code in codes:
                    changes[codes[code][0]].append((now, line[0].lower()))
            elif line.startswith("b"):
                match = re.match(r"b([01xXzZ]+)\s+(\S+)", line)
                if match and match.group(2) in codes:
                    code = match.group(2)
                    changes[codes[code][0]].append((now, match.group(1).lower()))

    return changes


def locate(changes, suffix: str):
    matches = [name for name in changes if name.endswith("." + suffix)]
    if not matches:
        raise KeyError(f"signal ending in {suffix!r} not found")
    if suffix == "expected_state":
        matches.sort(key=lambda name: ("dut_checker." not in name, len(name)))
    else:
        matches.sort(key=len)
    return changes[matches[0]]


def value_at(events: list[tuple[int, str]], time: int) -> str:
    value = "x"
    for event_time, event_value in events:
        if event_time > time:
            break
        value = event_value
    return value


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: render_prbs_waveform.py input.vcd output.png")

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    changes = read_vcd(input_path)
    lanes = [(label, locate(changes, suffix), is_bus) for label, suffix, is_bus in SIGNALS]

    width, height = 1500, 760
    left, right, top = 245, 35, 92
    lane_height = 66
    plot_width = width - left - right
    end_time = max(time for _, events, _ in lanes for time, _ in events)
    end_ns = max(100, (end_time + 999) // 1000)

    image = Image.new("RGB", (width, height), "#fbfcfe")
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=26)

    draw.text((left, 24), "PRBS-15 seed, hold, advance, and error detection", fill="#172033", font=title_font)
    draw.text((left, 57), "Captured from Vivado xsim; time in ns", fill="#526078", font=small)

    def xpos(time_ps: int) -> float:
        return left + (time_ps / (end_ns * 1000)) * plot_width

    for ns in range(0, end_ns + 1, 10):
        x = xpos(ns * 1000)
        draw.line((x, top - 8, x, top + lane_height * len(lanes)), fill="#dfe5ee", width=1)
        draw.text((x + 3, top - 28), str(ns), fill="#5f6b7d", font=small)

    for lane_index, (label, events, is_bus) in enumerate(lanes):
        y_mid = top + lane_index * lane_height + lane_height // 2
        draw.text((20, y_mid - 10), label, fill="#172033", font=font)
        draw.line((left, y_mid + 23, width - right, y_mid + 23), fill="#cbd4e1", width=1)

        if is_bus:
            segment_events = events + [(end_ns * 1000, "")]
            for index, (event_time, value) in enumerate(segment_events[:-1]):
                next_time = segment_events[index + 1][0]
                x1, x2 = xpos(event_time), xpos(next_time)
                draw.rectangle((x1, y_mid - 15, x2, y_mid + 15), outline="#315caa", width=2)
                if value and "x" not in value and "z" not in value:
                    text = f"0x{int(value, 2):04X}"
                else:
                    text = value.upper()
                if x2 - x1 > 56:
                    draw.text((x1 + 5, y_mid - 9), text, fill="#234a8f", font=small)
            continue

        all_times = sorted({0, end_ns * 1000, *(time for time, _ in events)})
        points = []
        for index, time in enumerate(all_times[:-1]):
            next_time = all_times[index + 1]
            value = value_at(events, time)
            y = y_mid - 14 if value == "1" else y_mid + 14
            points.append((xpos(time), y))
            points.append((xpos(next_time), y))
            if index + 1 < len(all_times) - 1:
                next_value = value_at(events, next_time)
                next_y = y_mid - 14 if next_value == "1" else y_mid + 14
                points.append((xpos(next_time), next_y))
        color = "#c33b4b" if label == "error_pulse" else "#18766b"
        draw.line(points, fill=color, width=3, joint="curve")

    # Mark the intentionally corrupted valid comparison and resulting pulse.
    error_events = locate(changes, "error_pulse")
    rising = next((time for time, value in error_events if value == "1"), None)
    if rising is not None:
        x = xpos(rising)
        draw.line((x, top - 8, x, top + lane_height * len(lanes)), fill="#c33b4b", width=2)
        draw.text((x + 7, top + lane_height * 5 - 25), "injected mismatch", fill="#a12838", font=small)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


if __name__ == "__main__":
    main()
