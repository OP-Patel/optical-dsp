from __future__ import annotations

from collections.abc import Iterator

from .protocol import Packet, PacketDecoder


class SerialTransport:
    def __init__(
        self,
        port: str,
        baudrate: int = 115_200,
        timeout: float = 1.0,
    ) -> None:
        try:
            import serial
        except ImportError as error:
            raise RuntimeError(
                "pyserial is required for hardware UART access: python -m pip install pyserial"
            ) from error

        self._serial = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=8,
            parity="N",
            stopbits=1,
            timeout=timeout,
        )
        self._decoder = PacketDecoder()

    def close(self) -> None:
        self._serial.close()

    def read_packets(self, chunk_size: int = 256) -> Iterator[Packet]:
        while self._serial.is_open:
            data = self._serial.read(chunk_size)
            if not data:
                continue
            yield from self._decoder.feed(data)

    def __enter__(self) -> SerialTransport:
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()
