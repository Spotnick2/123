"""Offline bar art study, using generated assets; not a game capture."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.release'
OUT.mkdir(exist_ok=True)
FONT = 'C:/Windows/Fonts/segoeui.ttf'


def font(size):
    return ImageFont.truetype(FONT, size)


def layer(canvas, name, center, size, color=(255, 255, 255), alpha=1):
    im = Image.open(ROOT / 'Media' / (name + '.tga')).convert('RGBA')
    im = im.resize(size, Image.Resampling.LANCZOS)
    import numpy as np
    a = np.array(im)
    for c in range(3):
        a[:, :, c] = a[:, :, c].astype(float) * color[c] / 255
    a[:, :, 3] = a[:, :, 3].astype(float) * alpha
    canvas.alpha_composite(Image.fromarray(a), (round(center[0]-size[0]/2), round(center[1]-size[1]/2)))


def bar(scale, bright):
    im = Image.new('RGBA', (467, 100), (190, 200, 210) if bright else (20, 23, 30))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 12, 466, 64), 12, fill=(36, 31, 46, 235), outline=(112, 104, 130))
    d.text((13, 28), '123', font=font(13), fill=(148, 130, 201))
    layer(im, 'Bar_Grip_32', (9, 38), (10, 26), alpha=.45)
    states = ['hover', 'unlearned', 'armor', 'missing', 'normal', 'waiting']
    colors = [(148,130,201), (102,110,94), (148,130,201), (255,59,31), (148,130,201), (122,255,31)]
    for i, (state, color) in enumerate(zip(states, colors)):
        cx = 68 + 60*i
        d.rectangle((cx-18, 20, cx+17, 55), fill=(52,51,59) if state in ('missing','unlearned') else (65,55,85))
        if state in ('armor','waiting'):
            layer(im, 'Bar_Glow_128', (cx,38), (56,56), color, .7)
        layer(im, 'Bar_Frame_64', (cx,38), (40,40), (204,204,204))
        layer(im, 'Bar_RimLight_64', (cx,38), (40,40), color, .7)
        if state == 'hover':
            layer(im, 'Bar_RimLight_64', (cx,38), (40,40), (217,199,255), .9)
        d = ImageDraw.Draw(im)
        if i == 4: d.text((cx+7,38), '3', font=font(13), fill='white')
        d.text((cx,72), state, font=font(10), fill='black' if bright else 'white', anchor='mt')
    layer(im, 'Bar_Divider_8x64', (402,38), (8,36), alpha=.18)
    d = ImageDraw.Draw(im)
    d.polygon([(420,27),(426,38),(420,49),(414,38)], fill=(160,115,220))
    d.text((435,28), '27', font=font(15), fill='white')
    return im.resize((round(467*scale), round(100*scale)), Image.Resampling.LANCZOS)


canvas = Image.new('RGBA', (780, 650), (29,31,39))
d = ImageDraw.Draw(canvas)
d.text((24,15), '123 bar — art study, not a game capture', font=font(22), fill='white')
d.text((24,48), 'Placeholder icons; approximate glass. Pulse shown at peak.', font=font(14), fill=(190,190,200))
y = 80
for scale, bright in [(1,False),(1,True),(1.5,False),(1.5,True)]:
    im = bar(scale, bright)
    canvas.alpha_composite(im, (24,y))
    y += im.height + 12
canvas.convert('RGB').save(OUT / 'bar-preview.png')
print(OUT / 'bar-preview.png')
