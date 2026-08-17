from __future__ import annotations

import argparse
import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from optical_dsp_host.analysis import (
    NOMINAL_SAMPLE_RATE_HZ,
    compare_levels,
    estimate_transition_samples,
    load_capture_csv,
    sha256_file,
    summarize_capture,
    summarize_capture_file,
)
from optical_dsp_host.protocol import CAPTURE_PACKET_TYPE, decode_capture_payload
from optical_dsp_host.serial_transport import SerialTransport

CONDITIONS = (
    "dark",
    "ambient",
    "off",
    "on",
    "training",
    "blocked",
    "misaligned",
)


def expected_switches(condition: str, rate_bps: int) -> tuple[int, int, int, int]:
    if condition in ("dark", "ambient", "off"):
        if rate_bps != 0:
            raise ValueError(f"{condition} captures must use --rate 0")
        return 0, 0, 0, 0

    if condition == "on":
        if rate_bps != 0:
            raise ValueError("on captures must use --rate 0")
        return 1, 0, 1, 0

    if condition == "training":
        if rate_bps == 0:
            raise ValueError("training captures require --rate 1000 or --rate 10000")
        return 1, 1, 0, int(rate_bps == 10000)

    if condition in ("blocked", "misaligned"):
        if rate_bps == 0:
            return 1, 0, 1, 0
        return 1, 1, 0, int(rate_bps == 10000)

    raise ValueError(f"unsupported condition: {condition}")


def safe_label(value: str) -> str:
    label = re.sub(r"[^a-zA-Z0-9_-]+", "-", value.strip()).strip("-")
    if not label:
        raise ValueError("metadata label contains no usable characters")
    return label.lower()


def capture_stem(
    detector: str,
    resistor_ohms: int,
    condition: str,
    rate_bps: int,
    run_number: int,
) -> str:
    rate_label = "dc" if rate_bps == 0 else f"{rate_bps}bps"
    return (
        f"{safe_label(detector)}_r{resistor_ohms}ohm_"
        f"{safe_label(condition)}_{rate_label}_run{run_number:02d}"
    )


def write_capture_csv(path: Path, start_index: int, samples: tuple[int, ...]) -> None:
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(("sample_index", "raw_code"))

        for offset, sample in enumerate(samples):
            writer.writerow((start_index + offset, sample))


def capture_command(args: argparse.Namespace) -> None:
    if args.resistor_ohms <= 0:
        raise ValueError("resistor value must be positive")
    if args.run <= 0:
        raise ValueError("run number must be positive")

    sw0, sw2, sw1, sw3 = expected_switches(args.condition, args.rate)

    stem = capture_stem(
        args.detector,
        args.resistor_ohms,
        args.condition,
        args.rate,
        args.run,
    )
    output_directory = args.output_dir
    csv_path = output_directory / f"{stem}.csv"
    metadata_path = output_directory / f"{stem}.json"

    if not args.force and (csv_path.exists() or metadata_path.exists()):
        raise FileExistsError(
            f"capture {stem} already exists; choose another run number or use --force"
        )

    output_directory.mkdir(parents=True, exist_ok=True)
    print(
        f"Expected switches: SW0={sw0} SW2={sw2} SW1={sw1} SW3={sw3} "
        f"({args.condition}, {'DC' if args.rate == 0 else f'{args.rate} bit/s'})"
    )
    print(f"Waiting on {args.port}. Press BTN1 to arm, then BTN2 to trigger.")

    with SerialTransport(args.port, timeout=args.timeout) as transport:
        for packet in transport.read_packets():
            if packet.packet_type != CAPTURE_PACKET_TYPE:
                continue

            capture = decode_capture_payload(packet)
            indices = tuple(
                capture.start_index + offset for offset in range(len(capture.samples))
            )
            statistics = summarize_capture(indices, capture.samples)
            write_capture_csv(csv_path, capture.start_index, capture.samples)

            metadata = {
                "schema_version": 1,
                "captured_utc": datetime.now(timezone.utc).isoformat(),
                "detector": args.detector,
                "resistor_ohms": args.resistor_ohms,
                "condition": args.condition,
                "rate_bps": args.rate,
                "run": args.run,
                "distance_cm": args.distance_cm,
                "ambient": args.ambient,
                "notes": args.notes,
                "packet_sequence": packet.sequence,
                "packet_crc_valid": True,
                "nominal_sample_rate_hz": NOMINAL_SAMPLE_RATE_HZ,
                "statistics": statistics.to_dict(),
                "csv_path": str(csv_path),
                "csv_sha256": sha256_file(csv_path),
            }
            metadata_path.write_text(
                json.dumps(metadata, indent=2) + "\n",
                encoding="utf-8",
            )

            print(
                f"Saved {statistics.sample_count} samples to {csv_path}\n"
                f"min={statistics.minimum} max={statistics.maximum} "
                f"mean={statistics.mean:.3f} "
                f"std={statistics.standard_deviation:.3f} "
                f"consecutive={statistics.indices_consecutive}\n"
                f"metadata={metadata_path}"
            )
            return


def summary_command(args: argparse.Namespace) -> None:
    for path in args.captures:
        statistics = summarize_capture_file(path)
        print(
            f"{path}: count={statistics.sample_count} "
            f"index={statistics.start_index}..{statistics.end_index} "
            f"min={statistics.minimum} max={statistics.maximum} "
            f"mean={statistics.mean:.3f} std={statistics.standard_deviation:.3f} "
            f"clip0={statistics.clipped_low_count} "
            f"clip4095={statistics.clipped_high_count}"
        )


def create_plots(
    off_path: Path,
    on_path: Path,
    training_paths: list[Path],
    plot_directory: Path,
) -> None:
    try:
        import matplotlib.pyplot as plt
    except ImportError as error:
        raise RuntimeError(
            "plotting requires matplotlib: python -m pip install matplotlib"
        ) from error

    _, off_samples = load_capture_csv(off_path)
    _, on_samples = load_capture_csv(on_path)
    plot_directory.mkdir(parents=True, exist_ok=True)

    plt.figure(figsize=(8, 4.5))
    plt.hist(off_samples, bins=40, alpha=0.65, label="laser off")
    plt.hist(on_samples, bins=40, alpha=0.65, label="laser on")
    plt.xlabel("XADC code")
    plt.ylabel("samples")
    plt.legend()
    plt.tight_layout()
    plt.savefig(plot_directory / "off-on-histogram.png", dpi=160)
    plt.close()

    for training_path in training_paths:
        _, training_samples = load_capture_csv(training_path)
        plt.figure(figsize=(10, 4.5))
        plt.plot(training_samples, linewidth=1)
        plt.xlabel("capture sample")
        plt.ylabel("XADC code")
        plt.title(training_path.stem)
        plt.tight_layout()
        plt.savefig(plot_directory / f"{training_path.stem}.png", dpi=160)
        plt.close()


def compare_command(args: argparse.Namespace) -> None:
    off_statistics = summarize_capture_file(args.off)
    on_statistics = summarize_capture_file(args.on)
    comparison = compare_levels(off_statistics, on_statistics)
    report: dict[str, object] = {
        "off_capture": str(args.off),
        "on_capture": str(args.on),
        "off_statistics": off_statistics.to_dict(),
        "on_statistics": on_statistics.to_dict(),
        "comparison": comparison.to_dict(),
        "training": [],
    }

    for training_path in args.training:
        _, training_samples = load_capture_csv(training_path)
        transitions = estimate_transition_samples(
            training_samples,
            off_statistics.mean,
            on_statistics.mean,
        )
        report["training"].append(
            {
                "capture": str(training_path),
                "transitions": transitions.to_dict(args.sample_rate),
            }
        )

    report_text = json.dumps(report, indent=2)
    print(report_text)

    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report_text + "\n", encoding="utf-8")

    if args.plot_dir is not None:
        create_plots(args.off, args.on, args.training, args.plot_dir)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Capture and compare labeled Milestone 8 BPW34 measurements."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    capture_parser = subparsers.add_parser("capture", help="receive one labeled capture")
    capture_parser.add_argument("port", help="serial port, for example COM5")
    capture_parser.add_argument("--detector", required=True, help="local ID, for example pd01")
    capture_parser.add_argument("--resistor-ohms", required=True, type=int)
    capture_parser.add_argument("--condition", required=True, choices=CONDITIONS)
    capture_parser.add_argument("--rate", type=int, choices=(0, 1000, 10000), default=0)
    capture_parser.add_argument("--run", type=int, default=1)
    capture_parser.add_argument("--distance-cm", type=float)
    capture_parser.add_argument("--ambient", default="room")
    capture_parser.add_argument("--notes", default="")
    capture_parser.add_argument("--timeout", type=float, default=1.0)
    capture_parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("artifacts/captures/milestone-08"),
    )
    capture_parser.add_argument("--force", action="store_true")
    capture_parser.set_defaults(handler=capture_command)

    summary_parser = subparsers.add_parser("summary", help="summarize saved CSV captures")
    summary_parser.add_argument("captures", type=Path, nargs="+")
    summary_parser.set_defaults(handler=summary_command)

    compare_parser = subparsers.add_parser("compare", help="compare OFF, ON, and training captures")
    compare_parser.add_argument("--off", required=True, type=Path)
    compare_parser.add_argument("--on", required=True, type=Path)
    compare_parser.add_argument("--training", type=Path, action="append", default=[])
    compare_parser.add_argument("--sample-rate", type=float, default=NOMINAL_SAMPLE_RATE_HZ)
    compare_parser.add_argument("--output", type=Path)
    compare_parser.add_argument("--plot-dir", type=Path)
    compare_parser.set_defaults(handler=compare_command)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    try:
        args.handler(args)
    except (FileExistsError, RuntimeError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
