from __future__ import annotations

import csv
import pathlib
import sys
import unittest

HOST_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HOST_ROOT))

from characterize_bpw34 import capture_stem, expected_switches, safe_label  # noqa: E402
from optical_dsp_host.analysis import (  # noqa: E402
    compare_levels,
    estimate_transition_samples,
    load_capture_csv,
    sha256_file,
    summarize_capture,
    summarize_capture_file,
)


class AnalysisTests(unittest.TestCase):
    def test_capture_statistics_and_nominal_voltage(self) -> None:
        statistics = summarize_capture((100, 101, 102, 103), (0, 2, 4, 4095))

        self.assertEqual(statistics.sample_count, 4)
        self.assertEqual(statistics.start_index, 100)
        self.assertEqual(statistics.end_index, 103)
        self.assertTrue(statistics.indices_consecutive)
        self.assertEqual(statistics.minimum, 0)
        self.assertEqual(statistics.maximum, 4095)
        self.assertEqual(statistics.span, 4095)
        self.assertAlmostEqual(statistics.mean, 1025.25)
        self.assertEqual(statistics.clipped_low_count, 1)
        self.assertEqual(statistics.clipped_high_count, 1)
        self.assertAlmostEqual(statistics.nominal_mean_volts, 1025.25 * 3.3 / 4095)

    def test_nonconsecutive_indices_are_visible(self) -> None:
        statistics = summarize_capture((10, 11, 13), (1, 2, 3))
        self.assertFalse(statistics.indices_consecutive)

    def test_invalid_capture_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            summarize_capture((), ())
        with self.assertRaises(ValueError):
            summarize_capture((0,), (4096,))
        with self.assertRaises(ValueError):
            summarize_capture((0, 1), (1,))

    def test_level_comparison(self) -> None:
        off = summarize_capture((0, 1, 2), (10, 12, 14))
        on = summarize_capture((3, 4, 5), (100, 102, 104))
        comparison = compare_levels(off, on)

        self.assertEqual(comparison.mean_off, 12)
        self.assertEqual(comparison.mean_on, 102)
        self.assertEqual(comparison.separation, 90)
        self.assertGreater(comparison.pooled_noise, 0)
        self.assertAlmostEqual(
            comparison.simple_quality,
            comparison.separation / comparison.pooled_noise,
        )

    def test_transition_estimation(self) -> None:
        samples = (0, 0, 2, 5, 8, 10, 10, 8, 5, 2, 0)
        transitions = estimate_transition_samples(samples, 0, 10)

        self.assertEqual(transitions.rising_samples, (4,))
        self.assertEqual(transitions.falling_samples, (4,))
        self.assertEqual(transitions.mean_rising_samples, 4)
        self.assertEqual(transitions.mean_falling_samples, 4)

    def test_csv_loading_summary_and_hash(self) -> None:
        capture_path = HOST_ROOT.parent / "artifacts" / "test-analysis-capture.csv"

        try:
            with capture_path.open("w", newline="", encoding="utf-8") as csv_file:
                writer = csv.writer(csv_file)
                writer.writerow(("sample_index", "raw_code"))
                writer.writerow((7, 100))
                writer.writerow((8, 101))

            indices, samples = load_capture_csv(capture_path)
            statistics = summarize_capture_file(capture_path)

            self.assertEqual(indices, (7, 8))
            self.assertEqual(samples, (100, 101))
            self.assertEqual(statistics.mean, 100.5)
            self.assertEqual(len(sha256_file(capture_path)), 64)
        finally:
            capture_path.unlink(missing_ok=True)

    def test_capture_filename_is_repeatable_and_safe(self) -> None:
        self.assertEqual(safe_label("PD 01 / left"), "pd-01-left")
        self.assertEqual(
            capture_stem("PD 01", 10_000, "training", 10_000, 3),
            "pd-01_r10000ohm_training_10000bps_run03",
        )
        self.assertEqual(
            capture_stem("PD 02", 100_000, "training", 10_000, 1, "centered"),
            "pd-02_r100000ohm_training_10000bps_centered_run01",
        )

    def test_expected_switches_match_condition_and_rate(self) -> None:
        self.assertEqual(expected_switches("off", 0), (0, 0, 0, 0))
        self.assertEqual(expected_switches("on", 0), (1, 0, 1, 0))
        self.assertEqual(expected_switches("training", 1000), (1, 1, 0, 0))
        self.assertEqual(expected_switches("training", 10000), (1, 1, 0, 1))
        self.assertEqual(expected_switches("blocked", 0), (1, 0, 1, 0))

        with self.assertRaises(ValueError):
            expected_switches("off", 1000)
        with self.assertRaises(ValueError):
            expected_switches("training", 0)


if __name__ == "__main__":
    unittest.main()
