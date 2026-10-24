from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ASSETS = Path(__file__).resolve().parent
COVERS = ('tetris', 'go', 'pain')
BACKGROUND = (17, 0, 17)

# Assemble the provided Sber symbol with a readable Cyrillic wordmark for the header.
with Image.open(ASSETS / 'logo_sber_48.png') as symbol:
    logo = Image.new('RGB', (128, 48), BACKGROUND)
    logo.paste(symbol.convert('RGB').resize((48, 48), Image.Resampling.LANCZOS), (0, 0))
draw = ImageDraw.Draw(logo)
font_path = Path('C:/Windows/Fonts/arialbd.ttf')
font = ImageFont.truetype(str(font_path), 25) if font_path.exists() else ImageFont.truetype('DejaVuSans-Bold.ttf', 25)
label = 'Сбер'
bounds = draw.textbbox((0, 0), label, font=font)
label_height = bounds[3] - bounds[1]
draw.text((57, (48-label_height)//2-bounds[1]), label, font=font, fill=(245, 247, 249))
logo.save(ASSETS / 'logo_sber_header_128x48.png')

images = [ASSETS / 'approval_192' / f'cover_{name}_192.png' for name in COVERS]
images.append(ASSETS / 'logo_sber_header_128x48.png')
images.append(ASSETS / 'logo_sber_sleep_192x52.png')
mem = ASSETS / 'music_covers_rgb444.mem'
count = 0
with mem.open('w', encoding='ascii', newline='\n') as output:
    for path in images:
        with Image.open(path) as image:
            rgb = image.convert('RGB')
            expected = ((192, 192) if 'cover_' in path.name else
                        (128, 48) if 'header' in path.name else (192, 52))
            if rgb.size != expected:
                raise SystemExit(f'{path.name} expected {expected}, got {rgb.size}')
            for red, green, blue in rgb.getdata():
                output.write(f'{((red >> 4) << 8) | ((green >> 4) << 4) | (blue >> 4):03X}\n')
                count += 1
print(f'Wrote {count} RGB444 ROM pixels to {mem}')
