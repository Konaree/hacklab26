from pathlib import Path
from PIL import Image, ImageChops
import sys
src=Path(sys.argv[1])
out=Path(sys.argv[2])
im=Image.open(src).convert('RGB')
r,g,b=im.split()
chroma=ImageChops.subtract(ImageChops.lighter(ImageChops.lighter(r,g),b), ImageChops.darker(ImageChops.darker(r,g),b))
# Keep the saturated blue-green logo and discard the faint gray dotted guide around it.
box=chroma.point(lambda v: 255 if v >= 42 else 0).getbbox()
if not box:
    raise SystemExit('No saturated logo pixels found')
left,top,right,bottom=box
side=max(right-left,bottom-top)
cx=(left+right)//2; cy=(top+bottom)//2
left=max(0,cx-side//2); top=max(0,cy-side//2)
right=min(im.width,left+side); bottom=min(im.height,top+side)
left=max(0,right-side); top=max(0,bottom-side)
# Alpha from color saturation removes the white background; antialiasing is retained when reduced.
alpha=chroma.point(lambda v: 0 if v < 15 else min(255,(v-15)*5))
rgba=Image.merge('RGBA',(*im.split(),alpha)).crop((left,top,right,bottom))
rgba=rgba.resize((48,48),Image.Resampling.LANCZOS)
bg=Image.new('RGB',(48,48),(17,0,17))
bg.paste(rgba,(0,0),rgba.getchannel('A'))
bg.save(out)
print(f'{out} from crop {(left,top,right,bottom)}')
