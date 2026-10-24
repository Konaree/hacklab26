from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
assets=Path(__file__).resolve().parent
icon=Image.open(assets/'logo_sber_48.png').convert('RGB')
out=Image.new('RGB',(128,48),(17,0,17))
out.paste(icon,(0,0))
draw=ImageDraw.Draw(out)
font_path=Path('C:/Windows/Fonts/arialbd.ttf')
font=ImageFont.truetype(str(font_path),25) if font_path.exists() else ImageFont.truetype('DejaVuSans-Bold.ttf',25)
text='Сбер'
bbox=draw.textbbox((0,0),text,font=font)
text_h=bbox[3]-bbox[1]
draw.text((57, (48-text_h)//2-bbox[1]),text,font=font,fill=(245,247,249))
out.save(assets/'logo_sber_header_128x48.png')
print('header logo ready',bbox)
