from __future__ import annotations

from dataclasses import dataclass

SYNC_BYTES = b"\xA5\x5A"
PROTOCOL_VERSION = 1
CAPTURE_PACKET_TYPE = 0x02
SAMPLE_FORMAT_U12_IN_U16_LE = 0x01
MAX_PAYLOAD_BYTES = 4096
HEADER_BYTES = 8
PACKET_OVERHEAD_BYTES = 10


class ProtocolError(ValueError):
    pass


class CrcError(ProtocolError):
    pass


@dataclass(frozen=True)
class Packet:
    version: int
    packet_type: int
    sequence: int
    payload: bytes


@dataclass(frozen=True)
class CapturePayload:
    start_index: int
    sample_format: int
    samples: tuple[int, ...]


def crc16_ccitt(data: bytes, initial: int = 0xFFFF) -> int:
    crc = initial

    for byte in data:
        crc ^= byte << 8

        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF

    return crc


def encode_packet(
    packet_type: int,
    payload: bytes,
    sequence: int,
    version: int = PROTOCOL_VERSION,
) -> bytes:
    if len(payload) > MAX_PAYLOAD_BYTES:
        raise ProtocolError("payload exceeds the protocol maximum")
    if not 0 <= packet_type <= 0xFF:
        raise ProtocolError("packet type must fit in one byte")
    if not 0 <= version <= 0xFF:
        raise ProtocolError("version must fit in one byte")
    if not 0 <= sequence <= 0xFFFF:
        raise ProtocolError("sequence must fit in two bytes")

    covered = bytearray((version, packet_type))
    covered.extend(len(payload).to_bytes(2, "little"))
    covered.extend(sequence.to_bytes(2, "little"))
    covered.extend(payload)
    crc = crc16_ccitt(covered)

    return SYNC_BYTES + bytes(covered) + crc.to_bytes(2, "little")


def decode_packet(frame: bytes) -> Packet:
    if len(frame) < PACKET_OVERHEAD_BYTES:
        raise ProtocolError("packet is shorter than the fixed overhead")
    if frame[:2] != SYNC_BYTES:
        raise ProtocolError("sync bytes are missing")

    payload_length = int.from_bytes(frame[4:6], "little")
    if payload_length > MAX_PAYLOAD_BYTES:
        raise ProtocolError("declared payload exceeds the protocol maximum")

    expected_length = PACKET_OVERHEAD_BYTES + payload_length
    if len(frame) != expected_length:
        raise ProtocolError(
            f"packet length mismatch: expected {expected_length}, got {len(frame)}"
        )

    covered = frame[2:-2]
    received_crc = int.from_bytes(frame[-2:], "little")
    expected_crc = crc16_ccitt(covered)
    if received_crc != expected_crc:
        raise CrcError(
            f"CRC mismatch: expected 0x{expected_crc:04X}, got 0x{received_crc:04X}"
        )

    return Packet(
        version=frame[2],
        packet_type=frame[3],
        sequence=int.from_bytes(frame[6:8], "little"),
        payload=bytes(frame[8:-2]),
    )


def decode_capture_payload(packet: Packet) -> CapturePayload:
    if packet.packet_type != CAPTURE_PACKET_TYPE:
        raise ProtocolError("packet is not a sample-capture packet")
    if len(packet.payload) < 11:
        raise ProtocolError("capture payload is shorter than its metadata")

    start_index = int.from_bytes(packet.payload[0:8], "little")
    sample_count = int.from_bytes(packet.payload[8:10], "little")
    sample_format = packet.payload[10]
    expected_length = 11 + (sample_count * 2)

    if len(packet.payload) != expected_length:
        raise ProtocolError("capture sample count does not match payload length")
    if sample_format != SAMPLE_FORMAT_U12_IN_U16_LE:
        raise ProtocolError(f"unsupported sample format 0x{sample_format:02X}")

    samples = []
    for offset in range(11, len(packet.payload), 2):
        sample = int.from_bytes(packet.payload[offset : offset + 2], "little")
        if sample > 0x0FFF:
            raise ProtocolError("12-bit sample contains nonzero upper bits")
        samples.append(sample)

    return CapturePayload(
        start_index=start_index,
        sample_format=sample_format,
        samples=tuple(samples),
    )


class PacketDecoder:
    def __init__(self, max_payload_bytes: int = MAX_PAYLOAD_BYTES) -> None:
        self.max_payload_bytes = max_payload_bytes
        self._buffer = bytearray()
        self.crc_errors = 0
        self.length_errors = 0
        self.discarded_bytes = 0

    def feed(self, data: bytes) -> list[Packet]:
        self._buffer.extend(data)
        packets = []

        while True:
            sync_position = self._buffer.find(SYNC_BYTES)
            if sync_position < 0:
                keep = 1 if self._buffer.endswith(SYNC_BYTES[:1]) else 0
                self.discarded_bytes += len(self._buffer) - keep
                if keep:
                    self._buffer[:] = self._buffer[-1:]
                else:
                    self._buffer.clear()
                break

            if sync_position > 0:
                self.discarded_bytes += sync_position
                del self._buffer[:sync_position]

            if len(self._buffer) < HEADER_BYTES:
                break

            payload_length = int.from_bytes(self._buffer[4:6], "little")
            if payload_length > self.max_payload_bytes:
                self.length_errors += 1
                self.discarded_bytes += 1
                del self._buffer[0]
                continue

            frame_length = PACKET_OVERHEAD_BYTES + payload_length
            if len(self._buffer) < frame_length:
                break

            frame = bytes(self._buffer[:frame_length])
            try:
                packets.append(decode_packet(frame))
            except CrcError:
                self.crc_errors += 1
                self.discarded_bytes += 1
                del self._buffer[0]
                continue

            del self._buffer[:frame_length]

        return packets
