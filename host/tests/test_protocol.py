from __future__ import annotations

import pathlib
import sys
import unittest

HOST_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HOST_ROOT))

from optical_dsp_host.protocol import (  # noqa: E402
    CAPTURE_PACKET_TYPE,
    CrcError,
    PacketDecoder,
    ProtocolError,
    crc16_ccitt,
    decode_capture_payload,
    decode_packet,
    encode_packet,
)


class ProtocolTests(unittest.TestCase):
    def test_crc_published_check_vector(self) -> None:
        self.assertEqual(crc16_ccitt(b"123456789"), 0x29B1)

    def test_zero_length_packet(self) -> None:
        frame = encode_packet(packet_type=0x01, payload=b"", sequence=0x1234)
        packet = decode_packet(frame)
        self.assertEqual(packet.version, 1)
        self.assertEqual(packet.packet_type, 0x01)
        self.assertEqual(packet.sequence, 0x1234)
        self.assertEqual(packet.payload, b"")

    def test_capture_packet_round_trip(self) -> None:
        samples = (0x000, 0x001, 0x800, 0xFFF)
        payload = bytearray((0x8877665544332211).to_bytes(8, "little"))
        payload.extend(len(samples).to_bytes(2, "little"))
        payload.append(0x01)
        for sample in samples:
            payload.extend(sample.to_bytes(2, "little"))

        frame = encode_packet(CAPTURE_PACKET_TYPE, bytes(payload), sequence=7)
        capture = decode_capture_payload(decode_packet(frame))
        self.assertEqual(capture.start_index, 0x8877665544332211)
        self.assertEqual(capture.samples, samples)

    def test_rtl_capture_fixture(self) -> None:
        fixture_path = pathlib.Path(__file__).parent / "fixtures" / "rtl_capture_packet.hex"
        frame = bytes(int(line, 16) for line in fixture_path.read_text().splitlines())
        packet = decode_packet(frame)
        capture = decode_capture_payload(packet)
        self.assertEqual(packet.sequence, 0)
        self.assertEqual(capture.start_index, 0x1122334455667788)
        self.assertEqual(capture.samples, (0x001, 0xABC, 0x800, 0xFFF))

    def test_crc_corruption_rejected(self) -> None:
        frame = bytearray(encode_packet(0x01, b"abcdef", sequence=2))
        frame[9] ^= 0x40
        with self.assertRaises(CrcError):
            decode_packet(bytes(frame))

    def test_stream_decoder_resynchronizes(self) -> None:
        first = encode_packet(0x01, b"first", sequence=1)
        corrupt = bytearray(encode_packet(0x01, b"broken", sequence=2))
        corrupt[8] ^= 0x01
        second = encode_packet(0x01, b"second", sequence=3)
        stream = b"noise" + first + bytes(corrupt) + b"partial" + second

        decoder = PacketDecoder()
        packets = []
        for split in range(0, len(stream), 3):
            packets.extend(decoder.feed(stream[split : split + 3]))

        self.assertEqual([packet.sequence for packet in packets], [1, 3])
        self.assertEqual(decoder.crc_errors, 1)
        self.assertGreater(decoder.discarded_bytes, 0)

    def test_length_and_sample_format_validation(self) -> None:
        with self.assertRaises(ProtocolError):
            encode_packet(0x01, bytes(4097), sequence=0)

        payload = (0).to_bytes(8, "little") + (1).to_bytes(2, "little") + b"\x02\x00\x00"
        packet = decode_packet(encode_packet(CAPTURE_PACKET_TYPE, payload, 0))
        with self.assertRaises(ProtocolError):
            decode_capture_payload(packet)


if __name__ == "__main__":
    unittest.main()
