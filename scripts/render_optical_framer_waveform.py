"""Render the focused optical framer VCD evidence as a readable PNG."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


SIGNALS = [
    ("symbol_ce", "symbol_ce", False),
    ("tx_bit", "tx_bit", False),
    ("frame_start", "frame_start", False),
    ("payload_start", "payload_start", False),
    ("frame_state", "frame_state", True),
    ("field_index", "field_index", True),
    ("prbs_load_seed", "prbs_load_seed", False),
    ("prbs_advance", "prbs_advance", False),
]

STATE_NAMES = {0: "PREAMBLE", 1: "SYNC", 2: "SEQUENCE", 3: "PAYLOAD"}


def read_vcd(path: Path):
    scopes = []
    codes = {}
    changes = {}
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
                code, name = parts[3], parts[4]
                full_name = ".".join([*scopes, name])
                codes[code] = full_name
                changes.setdefault(full_name, [])
            elif line.startswith("#"):
                now = int(line[1:])
            elif line and line[0] in "01xXzZ":
                code = line[1:]
                if code in codes:
                    changes[codes[code]].append((now, line[0].lower()))
            elif line.startswith("b"):
                match = re.match(r"b([01xXzZ]+)\s+(\S+)", line)
                if match and match.group(2) in codes:
                    changes[codes[match.group(2)]].append((now, match.group(1).lower()))

    return changes


def locate(changes, suffix):
    matches = [name for name in changes if name.endswith("." + suffix)]
    matches.sort(key=lambda name: (".dut." not in name, len(name)))
    if not matches:
        raise KeyError(f"signal ending in {suffix!r} not found")
    return changes[matches[0]]


def value_at(events, time):
    value = "x"
    for event_time, event_value in events:
        if event_time > time:
            break
        value = event_value
    return value


def bus_text(label, value):
    if "x" in value or "z" in value:
        return value.upper()
    number = int(value, 2)
    if label == "frame_state":
        return STATE_NAMES.get(number, str(number))
    return str(number)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: render_optical_framer_waveform.py input.vcd output.png")

    changes = read_vcd(Path(sys.argv[1]))
    lanes = [(label, locate(changes, suffix), is_bus) for label, suffix, is_bus in SIGNALS]
    width, height = 1600, 700
    left, right, top = 210, 35, 92
    lane_height = 70
    plot_width = width - left - right
    end_time = max(time for _, events, _ in lanes for time, _ in events)

    image = Image.new("RGB", (width, height), "#fbfcfe")
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default(size=18)
    small = ImageFont.load_default(size=14)
    title_font = ImageFont.load_default(size=25)

    draw.text((left, 22), "Optical framer field transitions and symbol-enable stall", fill="#172033", font=title_font)
    draw.text((left, 55), "Vivado xsim capture; state and index advance only on symbol_ce", fill="#526078", font=small)

    def xpos(time_ps):
        return left + (time_ps / end_time) * plot_width

    for lane_index, (label, events, is_bus) in enumerate(lanes):
        y_mid = top + lane_index * lane_height + lane_height // 2
        draw.text((18, y_mid - 10), label, fill="#172033", font=font)
        draw.line((left, y_mid + 23, width - right, y_mid + 23), fill="#d6dde8", width=1)

        event_times = sorted({0, end_time, *(time for time, _ in events)})
        if is_bus:
            for index, event_time in enumerate(event_times[:-1]):
                next_time = event_times[index + 1]
                value = value_at(events, event_time)
                x1, x2 = xpos(event_time), xpos(next_time)
                draw.rectangle((x1, y_mid - 15, x2, y_mid + 15), outline="#315caa", width=2)
                label_text = bus_text(label, value)
                if x2 - x1 > draw.textlength(label_text, font=small) + 8:
                    draw.text((x1 + 4, y_mid - 9), label_text, fill="#234a8f", font=small)
            continue

        points = []
        for index, event_time in enumerate(event_times[:-1]):
            next_time = event_times[index + 1]
            value = value_at(events, event_time)
            y = y_mid - 14 if value == "1" else y_mid + 14
            points.extend([(xpos(event_time), y), (xpos(next_time), y)])
            if index + 1 < len(event_times) - 1:
                next_value = value_at(events, next_time)
                next_y = y_mid - 14 if next_value == "1" else y_mid + 14
                points.append((xpos(next_time), next_y))
        draw.line(points, fill="#18766b", width=3)

    output_path = Path(sys.argv[2])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path)


if __name__ == "__main__":
    main()
