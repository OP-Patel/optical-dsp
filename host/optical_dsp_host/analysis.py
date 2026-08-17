from __future__ import annotations

import csv
import hashlib
import math
import statistics
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

ADC_MAX_CODE = 4095
NOMINAL_A0_FULL_SCALE_VOLTS = 3.3
NOMINAL_SAMPLE_RATE_HZ = 6_250_000 / 26


@dataclass(frozen=True)
class CaptureStatistics:
    sample_count: int
    start_index: int
    end_index: int
    indices_consecutive: bool
    minimum: int
    maximum: int
    mean: float
    standard_deviation: float
    span: int
    clipped_low_count: int
    clipped_high_count: int
    nominal_mean_volts: float

    def to_dict(self) -> dict[str, int | float | bool]:
        return asdict(self)


@dataclass(frozen=True)
class LevelComparison:
    mean_off: float
    mean_on: float
    separation: float
    pooled_noise: float
    simple_quality: float | None

    def to_dict(self) -> dict[str, float | None]:
        return asdict(self)


@dataclass(frozen=True)
class TransitionStatistics:
    lower_threshold: float
    upper_threshold: float
    rising_samples: tuple[int, ...]
    falling_samples: tuple[int, ...]

    @property
    def mean_rising_samples(self) -> float | None:
        if not self.rising_samples:
            return None
        return statistics.fmean(self.rising_samples)

    @property
    def mean_falling_samples(self) -> float | None:
        if not self.falling_samples:
            return None
        return statistics.fmean(self.falling_samples)

    def to_dict(self, sample_rate_hz: float) -> dict[str, object]:
        rising_seconds = None
        falling_seconds = None

        if self.mean_rising_samples is not None:
            rising_seconds = self.mean_rising_samples / sample_rate_hz
        if self.mean_falling_samples is not None:
            falling_seconds = self.mean_falling_samples / sample_rate_hz

        return {
            "lower_threshold": self.lower_threshold,
            "upper_threshold": self.upper_threshold,
            "rising_samples": list(self.rising_samples),
            "falling_samples": list(self.falling_samples),
            "mean_rising_samples": self.mean_rising_samples,
            "mean_falling_samples": self.mean_falling_samples,
            "mean_rising_seconds": rising_seconds,
            "mean_falling_seconds": falling_seconds,
        }


def load_capture_csv(path: Path) -> tuple[tuple[int, ...], tuple[int, ...]]:
    indices = []
    samples = []

    with path.open(newline="", encoding="utf-8") as csv_file:
        reader = csv.DictReader(csv_file)
        if reader.fieldnames != ["sample_index", "raw_code"]:
            raise ValueError(f"{path} does not have the expected capture columns")

        for row in reader:
            indices.append(int(row["sample_index"]))
            samples.append(int(row["raw_code"]))

    if not samples:
        raise ValueError(f"{path} contains no samples")

    return tuple(indices), tuple(samples)


def summarize_capture(
    indices: Sequence[int],
    samples: Sequence[int],
) -> CaptureStatistics:
    if not samples:
        raise ValueError("capture contains no samples")
    if len(indices) != len(samples):
        raise ValueError("sample indices and codes have different lengths")
    if any(sample < 0 or sample > ADC_MAX_CODE for sample in samples):
        raise ValueError("capture contains a code outside the 12-bit range")

    consecutive = all(
        current == previous + 1
        for previous, current in zip(indices, indices[1:])
    )
    sample_mean = statistics.fmean(samples)

    return CaptureStatistics(
        sample_count=len(samples),
        start_index=indices[0],
        end_index=indices[-1],
        indices_consecutive=consecutive,
        minimum=min(samples),
        maximum=max(samples),
        mean=sample_mean,
        standard_deviation=statistics.pstdev(samples),
        span=max(samples) - min(samples),
        clipped_low_count=sum(sample == 0 for sample in samples),
        clipped_high_count=sum(sample == ADC_MAX_CODE for sample in samples),
        nominal_mean_volts=sample_mean * NOMINAL_A0_FULL_SCALE_VOLTS / ADC_MAX_CODE,
    )


def summarize_capture_file(path: Path) -> CaptureStatistics:
    indices, samples = load_capture_csv(path)
    return summarize_capture(indices, samples)


def compare_levels(
    off_statistics: CaptureStatistics,
    on_statistics: CaptureStatistics,
) -> LevelComparison:
    separation = on_statistics.mean - off_statistics.mean
    pooled_noise = math.sqrt(
        off_statistics.standard_deviation**2
        + on_statistics.standard_deviation**2
    )
    simple_quality = None if pooled_noise == 0 else separation / pooled_noise

    return LevelComparison(
        mean_off=off_statistics.mean,
        mean_on=on_statistics.mean,
        separation=separation,
        pooled_noise=pooled_noise,
        simple_quality=simple_quality,
    )


def estimate_transition_samples(
    samples: Sequence[int],
    low_level: float,
    high_level: float,
) -> TransitionStatistics:
    if high_level <= low_level:
        raise ValueError("high level must be greater than low level")
    if len(samples) < 2:
        raise ValueError("at least two training samples are required")

    level_span = high_level - low_level
    lower_threshold = low_level + (0.1 * level_span)
    upper_threshold = low_level + (0.9 * level_span)
    rising_samples = []
    falling_samples = []
    rising_start = None
    falling_start = None

    for sample_number in range(1, len(samples)):
        previous = samples[sample_number - 1]
        current = samples[sample_number]

        if rising_start is None and previous <= lower_threshold < current:
            rising_start = sample_number - 1
        if rising_start is not None:
            if current >= upper_threshold:
                rising_samples.append(sample_number - rising_start)
                rising_start = None
            elif current <= lower_threshold and sample_number > rising_start + 1:
                rising_start = None

        if falling_start is None and previous >= upper_threshold > current:
            falling_start = sample_number - 1
        if falling_start is not None:
            if current <= lower_threshold:
                falling_samples.append(sample_number - falling_start)
                falling_start = None
            elif current >= upper_threshold and sample_number > falling_start + 1:
                falling_start = None

    return TransitionStatistics(
        lower_threshold=lower_threshold,
        upper_threshold=upper_threshold,
        rising_samples=tuple(rising_samples),
        falling_samples=tuple(falling_samples),
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as source_file:
        for block in iter(lambda: source_file.read(65536), b""):
            digest.update(block)

    return digest.hexdigest().upper()

