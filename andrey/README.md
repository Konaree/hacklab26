# PS/2 WAV player with VGA and accelerometer auto-sleep

This is the integrated Nexys A7-100T RTL project. The original PS/2 controls,
VGA renderer, seven-segment display and `vga_clk40` Clocking Wizard remain the
base. The WAV reader, SD SPI controller, audio meter and ADXL362 auto-sleep
logic are connected under `player_top`.

## Controls

Keyboard is PS/2, Set 2:

| Key | Action |
| --- | --- |
| `1`, `2`, `3` | Select `TRACK001.WAV`, `TRACK002.WAV`, `TRACK003.WAV` |
| `N` | Next track (wraps after track 3) |
| `B` | Previous track (wraps before track 1) |
| `Space` | Start, pause, or resume playback |
| `S` | Stop and reload the selected track from its beginning |

Nexys buttons and switches do not select or switch tracks. `SW0` only enables
automatic sleep: after 60 seconds without PS/2 activity or detected motion,
the audio pauses and the display shows a centered Sber logo on black. Keyboard activity or motion wakes it and restores the player screen.
With `SW0` low, auto-sleep is disabled. The ADXL362 is polled over SPI.

The VGA progress bar, elapsed time and duration use WAV payload size and the
number of PCM samples consumed by the player. The sixteen mono LEDs show the averaged PCM amplitude as a level bar. RGB LED16
changes color and brightness with that level; RGB LED17 briefly flashes on sharp
increases in the envelope. The eight-band on-screen spectrum remains a separate
frequency-band display. The screen spectrum is calculated separately by
`audio_spectrum_meter.sv`: eight broad octave-style bands are formed from
low-pass filter differences, and each bar shows the mean squared signal over
1024 samples (about 21 ms at 48 kHz). This is a compact filter-bank analyzer,
not an FFT. The board audio amplifier is driven with fixed volume; PWM audio is
routed to the Nexys A7 audio jack.

## VGA player screen and artwork

`src/rtl/music_renderer.sv` draws the player screen directly in RTL at 800x600:
playlist and selected-track highlight, track and artist names, elapsed/total
time, sample-based progress bar, the eight-band spectrum, and the Sber mark and
wordmark.
The three cover images are stored as 192x192 RGB444 pixels (12 bits per pixel),
then enlarged 2x to 384x384 by the renderer. The 128x48 header logo and a 192x52 centered sleep logo are stored after
the covers in the same synchronous block ROM. The sleep logo is enlarged 2x while rendering. The complete ROM has 126,720 entries;
the three cover images use 43.8% fewer pixels than the former 256x256 versions.

The `.mem` file is included in the Vivado Tcl project as a Memory Initialization
File. Source PNGs and the approved 192x192 cover variants are kept beside it. To rebuild the images and
memory file, run `python .\src\rtl\assets\build_music_rom.py` with Pillow
installed. `player_screen_preview.png` is a static preview of the RTL layout; `player_sleep_preview.png` shows the accelerometer sleep screen. The adjacent
`player_screen_spectrum_demo.gif` shows an illustrative animation; on the board,
the spectrum levels come from the live WAV samples.

The RTL uses transliterated ASCII for track names because its built-in bitmap
font contains Latin letters and digits. Vivado 2019.2 synthesis completed with no
errors or warnings and used 97 of the Nexys A7-100T's 135 BRAM blocks. A test
implementation produced a bitstream, but its routed timing report has WNS about
−2.3 ns and DRC reports REQP-1839 warnings for BRAM address inputs driven by
asynchronously reset registers. Treat that bitstream as a build check, not as a
timing-clean release; timing and the BRAM reset warnings still need attention.

Vivado batch mode raised `TclStackFree` when run from this machine's Cyrillic
user-directory path. The full test therefore ran from an ASCII-only copy of the
same project. Keep the project under an ASCII-only path when using this batch
script with Vivado 2019.2.

## SD card and WAV format

The player supports three fixed short filenames in the FAT32 root directory:
`TRACK001.WAV`, `TRACK002.WAV`, and `TRACK003.WAV`. Files must be canonical
44-byte-header WAV, unsigned PCM, mono, 8-bit, 48 kHz. The present FAT32 reader
uses the first root-directory sector and requires each file's data clusters to
be physically contiguous. It does not follow fragmented FAT chains, subfolders,
long file names, or extended WAV metadata chunks. Use an MBR-partitioned FAT32
card with the three WAV files in its root directory.

Example conversion with FFmpeg:

```text
ffmpeg -i input.mp3 -map_metadata -1 -ac 1 -ar 48000 -c:a pcm_u8 TRACK001.WAV
```

## Build

Open Vivado Tcl Console in this directory and run:

```tcl
source src/tcl/build_music_player.tcl
```

The script creates a regular RTL project for `xc7a100tcsg324-1`; it uses the
existing `src/ipcores/vga_clk40.xci`, the integrated XDC, and no Block Design or
MicroBlaze. Run synthesis and implementation to generate
`vivado_music_player/player_music.runs/impl_1/player_top.bit`.

## Third-party sources

`fat32_wav_player.sv`, `sd_spi_sector.sv`, and `spi_byte_master.sv` are MIT-
licensed code adapted from `Konaree/hacklab26`, branch `konaree`, commit
`bdd259e`. Preserve their license notices and credit this source in both the
hackathon expert message and the project presentation. The PS/2/VGA base,
top-level integration, timer wiring, LED meter wiring and keyboard controls
are team integration. The five ADXL362/auto-sleep modules were supplied for
this project; retain their original notices if redistributing them.
