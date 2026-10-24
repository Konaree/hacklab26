from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
assets=Path(__file__).resolve().parent
outdir=assets/'approval_192'
outdir.mkdir(exist_ok=True)
names=[('tetris','Тетрис'),('go','Снаружи всех измерений'),('pain','Pain')]
font_path=Path('C:/Windows/Fonts/arial.ttf')
font_bold_path=Path('C:/Windows/Fonts/arialbd.ttf')
font=ImageFont.truetype(str(font_path),22) if font_path.exists() else ImageFont.load_default()
bold=ImageFont.truetype(str(font_bold_path),24) if font_bold_path.exists() else font
card_w, card_h=900, 500
sheet=Image.new('RGB',(card_w,card_h*len(names)),(21,23,28))
draw=ImageDraw.Draw(sheet)
old_total=0
new_total=0
for i,(key,title) in enumerate(names):
    original_path=assets/f'cover_{key}_256.png'
    with Image.open(original_path) as im:
        original=im.convert('RGB')
    candidate=original.resize((192,192),Image.Resampling.LANCZOS)
    candidate_path=outdir/f'cover_{key}_192.png'
    candidate.save(candidate_path,format='PNG',optimize=True)
    view_original=original.resize((384,384),Image.Resampling.NEAREST)
    view_candidate=candidate.resize((384,384),Image.Resampling.NEAREST)
    y=i*card_h
    draw.text((24,y+12),title,font=bold,fill=(240,244,248))
    draw.text((24,y+52),'Сейчас: ROM 256×256',font=font,fill=(165,178,190))
    draw.text((470,y+52),'Кандидат: ROM 192×192',font=font,fill=(91,224,179))
    sheet.paste(view_original,(24,y+92))
    sheet.paste(view_candidate,(470,y+92))
    old_total += original_path.stat().st_size
    new_total += candidate_path.stat().st_size
    del original
sheet.save(outdir/'cover_comparison.png',optimize=True)
rom_old=3*256*256
rom_new=3*192*192
print(f'Comparison: {outdir / "cover_comparison.png"}')
print(f'PNG bytes (resized originals): {old_total}; candidate PNGs: {new_total}; reduction: {(old_total-new_total)/old_total*100:.1f}%')
print(f'Cover ROM pixels: {rom_old} -> {rom_new}; reduction: {(rom_old-rom_new)/rom_old*100:.1f}%')

