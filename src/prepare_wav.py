#!/usr/bin/env python3
"""Convert an unsigned 8-bit 48 kHz mono WAV to canonical 44-byte RIFF/WAVE.

Usage:
    python prepare_wav.py input.wav TRACK001.WAV

Convert other formats first, e.g.:
    ffmpeg -i song.mp3 -ac 1 -ar 48000 -c:a pcm_u8 input.wav
"""

from __future__ import annotations

import argparse
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 48_000
NUM_CHANNELS = 1
BITS_PER_SAMPLE = 8
MAX_AUDIO_SIZE = 0xFFFF_FFFF - 36


def create_header(audio_size: int) -> bytes:
    """Construct a canonical 44-byte PCM WAV header (little-endian)."""
    bytes_per_sample = BITS_PER_SAMPLE // 8
    block_align = NUM_CHANNELS * bytes_per_sample
    byte_rate = SAMPLE_RATE * block_align

    header = (
        b"RIFF"
        + struct.pack("<I", 36 + audio_size)
        + b"WAVE"
        + b"fmt "
        + struct.pack(
            "<IHHIIHH",
            16,
            1,
            NUM_CHANNELS,
            SAMPLE_RATE,
            byte_rate,
            block_align,
            BITS_PER_SAMPLE,
        )
        + b"data"
        + struct.pack("<I", audio_size)
    )
    assert len(header) == 44
    return header


def convert(input_file: Path, output_file: Path) -> None:
    with wave.open(str(input_file), "rb") as source:
        actual_format = (
            source.getnchannels(),
            source.getsampwidth(),
            source.getframerate(),
            source.getcomptype(),
        )
        expected_format = (1, 1, SAMPLE_RATE, "NONE")
        if actual_format != expected_format:
            raise ValueError(
                f"Expected 8-bit mono PCM at 48000 Hz. Got {actual_format!r}. "
                "Convert the source with ffmpeg first."
            )
        samples = source.readframes(source.getnframes())

    if len(samples) > MAX_AUDIO_SIZE:
        raise ValueError("WAV file exceeds RIFF's 32-bit size limit")

    output_file.write_bytes(create_header(len(samples)) + samples)
    duration = len(samples) / SAMPLE_RATE
    print(f"Created {output_file} | PCM bytes: {len(samples)} | {duration:.2f} s")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Input WAV file")
    parser.add_argument("output", type=Path, help="Canonical output WAV file")
    args = parser.parse_args()
    convert(args.input, args.output)


if __name__ == "__main__":
    main()
