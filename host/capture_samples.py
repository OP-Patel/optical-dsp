from __future__ import annotations

import argparse
import csv
from pathlib import Path

from optical_dsp_host.protocol import CAPTURE_PACKET_TYPE, decode_capture_payload
from optical_dsp_host.serial_transport import SerialTransport


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Receive one Milestone 7 capture packet and save its samples as CSV."
    )
    parser.add_argument("port", help="serial port, for example COM5")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("capture.csv"),
        help="CSV output path (default: capture.csv)",
    )
    parser.add_argument("--timeout", type=float, default=1.0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    print(f"Waiting for a capture packet on {args.port}...")
    with SerialTransport(args.port, timeout=args.timeout) as transport:
        for packet in transport.read_packets():
            if packet.packet_type != CAPTURE_PACKET_TYPE:
                continue

            capture = decode_capture_payload(packet)
            args.output.parent.mkdir(parents=True, exist_ok=True)

            with args.output.open("w", newline="", encoding="utf-8") as csv_file:
                writer = csv.writer(csv_file)
                writer.writerow(("sample_index", "raw_code"))

                for offset, sample in enumerate(capture.samples):
                    writer.writerow((capture.start_index + offset, sample))

            if capture.samples:
                sample_min = min(capture.samples)
                sample_max = max(capture.samples)
                sample_mean = sum(capture.samples) / len(capture.samples)
            else:
                sample_min = 0
                sample_max = 0
                sample_mean = 0.0

            print(
                f"Saved {len(capture.samples)} samples to {args.output} "
                f"(sequence={packet.sequence}, start={capture.start_index}, "
                f"min={sample_min}, max={sample_max}, mean={sample_mean:.2f})"
            )
            return


if __name__ == "__main__":
    main()
