from pathlib import Path
import math
import re
from PIL import Image, ImageDraw

ASSETS = Path(__file__).resolve().parent
RTL = ASSETS.parent / "music_renderer.sv"
OUT = ASSETS / "player_screen_preview.png"
GIF = ASSETS / "player_screen_spectrum_demo.gif"
W, H = 800, 600


def rgb444(value):
    return tuple(((value >> shift) & 15) * 17 for shift in (8, 4, 0))

source = RTL.read_text(encoding="utf-8")
font_body = source.split("function automatic logic [34:0] glyph", 1)[1].split("endfunction", 1)[0]
font = {}
for char, body in re.findall(r'"(.)"\s*:\s*glyph\s*=\s*\{([^}]+)\}', font_body):
    rows = re.findall(r"5'b([01]{5})", body)
    if len(rows) == 7:
        font[char] = rows

image = Image.new("RGB", (W, H), rgb444(0x101))
draw = ImageDraw.Draw(image)


def rect(x0, y0, x1, y1, color):
    if x1 > x0 and y1 > y0:
        draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill=rgb444(color))


def text(value, x0, y0, scale, color):
    for char_i, char in enumerate(value):
        rows = font.get(char, ["00000"] * 7)
        for row, bits in enumerate(rows):
            for col, bit in enumerate(bits):
                if bit == "1":
                    rect(x0 + char_i * 6 * scale + col * scale,
                         y0 + row * scale,
                         x0 + char_i * 6 * scale + (col + 1) * scale,
                         y0 + row * scale + scale, color)


# Header and two-column background.
rect(0, 0, W, 54, 0x101)
rect(0, 53, W, 54, 0x233)
rect(0, 54, 344, H, 0x111)
text("MY MUSIC", 32, 18, 2, 0xDDE)
logo = Image.open(ASSETS / "logo_sber_header_128x48.png").convert("RGB")
image.paste(logo, (650, 3))

# Playlist. Track 1 is selected in this preview.
titles = ["TETRIS", "S.N.V.I.", "PAIN"]
artists = ["KOROBEYNIKI", "GRAZHDANSKAYA OBORONA", "THREE DAYS GRACE"]
for i in range(3):
    row_y = 96 + i * 72
    rect(30, row_y, 330, row_y + 56, 0x132 if i == 0 else 0x111)
    if i == 0:
        rect(30, row_y, 35, row_y + 56, 0x5DB)
    text(f"0{i+1}", 48, row_y + 13, 2, 0x6EB if i == 0 else 0x687)
    text(titles[i], 86, row_y + 10, 2, 0xFFF if i == 0 else 0xCCD)
    text(artists[i], 86, row_y + 34, 1, 0x8CA if i == 0 else 0x788)

# Cover uses the approved 192x192 ROM image enlarged 2x as in the RTL.
rect(365, 77, 755, 467, 0x245)
cover = Image.open(ASSETS / "approval_192/cover_tetris_192.png").convert("RGB")
image.paste(cover.resize((384, 384), Image.Resampling.NEAREST), (368, 80))
draw = ImageDraw.Draw(image)
text("TETRIS", 368, 476, 2, 0xFFF)
text("KOROBEYNIKI", 368, 516, 1, 0x9AB)

# Example playback state for the preview only: 00:42 / 03:18.
for i, char in enumerate("00:42"):
    text(char, 26 + i * 10, 551, 2, 0xEDE)
for i, char in enumerate("03:18"):
    text(char, 634 + i * 10, 551, 2, 0xEDE)
progress_pixels = 128
progress_pos = progress_pixels * 9 // 10
rect(86, 559, 626, 563, 0x344)
rect(86, 559, 86 + progress_pos, 563, 0x4D9)
cx, cy = 86 + progress_pos, 561
for py in range(cy - 4, cy + 5):
    for px in range(cx - 4, cx + 5):
        if abs(px - cx) + abs(py - cy) <= 7:
            rect(px, py, px + 1, py + 1, 0x6EB)

# Compact 16-band spectrum concept in the old meter's lower-right footprint.
# Heights here are illustrative; live height values require frequency-band RTL.
palette = [
    (236, 48, 56), (244, 105, 24), (244, 183, 31), (143, 218, 42),
    (31, 204, 137), (32, 181, 221), (67, 112, 242), (183, 62, 211),
]
base_levels = [6, 8, 12, 10, 7, 11, 15, 9]


def draw_spectrum(target, levels):
    baseline = 574
    x_start, group_pitch, bar_w = 696, 11, 3
    target.line((694, baseline, 783, baseline), fill=(33, 40, 47), width=1)
    for i, level in enumerate(levels):
        x0 = x_start + i * group_pitch
        height = max(0, min(15, int(level))) * 2
        second_height = height - (height >> 2)
        color = palette[i]
        for offset, bar_h in ((0, height), (4, second_height)):
            if bar_h == 0:
                continue
            target.rectangle((x0 + offset, baseline - bar_h, x0 + offset + bar_w - 1, baseline - 1), fill=color)
            reflection_h = bar_h // 3
            for row in range(reflection_h):
                fade = max(0.08, 0.34 * (1.0 - row / reflection_h))
                dim = tuple(int(17 + (channel - 17) * fade) for channel in color)
                y = baseline + 2 + row
                target.rectangle((x0 + offset, y, x0 + offset + bar_w - 1, y), fill=dim)


base_screen = image.copy()
static_frame = base_screen.copy()
draw_spectrum(ImageDraw.Draw(static_frame), base_levels)
static_frame.save(OUT)

frames = []
for frame_i in range(20):
    levels = []
    for band, base in enumerate(base_levels):
        wave = math.sin(frame_i * 0.48 + band * 0.66)
        detail = math.sin(frame_i * 0.21 - band * 0.37)
        levels.append(max(0, min(15, round(base + 3.0 * wave + 1.2 * detail))))
    frame = base_screen.copy()
    draw_spectrum(ImageDraw.Draw(frame), levels)
    frames.append(frame.convert("P", palette=Image.Palette.ADAPTIVE, colors=256))
frames[0].save(GIF, save_all=True, append_images=frames[1:], duration=110, loop=0, optimize=True)
print(OUT)
print(GIF)
