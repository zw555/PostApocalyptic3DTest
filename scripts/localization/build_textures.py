"""Offline original graphics; Pillow already installed. No AI or commercial artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import random

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/localization'
FONT = ROOT / 'assets/fonts/NotoSansSC.ttf'
OUT.mkdir(parents=True, exist_ok=True)

def font(size):
    f = ImageFont.truetype(str(FONT), size)
    f.set_variation_by_axes([600])
    return f

def center(d, text, y, size, fill, width):
    f = font(size)
    box = d.textbbox((0, 0), text, font=f)
    d.text(((width-(box[2]-box[0]))/2, y), text, font=f, fill=fill)

atlas = Image.new('RGB', (2048, 512))
items = [
    ('矿泉水', '清泉 · 饮用天然水', '#b6d6d0', '#264f68', '净含量 500毫升'),
    ('清香茶饮', '淡茶香 · 社区自选', '#d4bf85', '#4d5939', '净含量 500毫升'),
    ('家常桶面', '鲜香菌菇风味', '#9d4535', '#f2deb2', '净含量 100克'),
    ('家常罐头', '红焖豆 · 即食食品', '#d9c8a2', '#783e34', '净含量 200克'),
]
for index, (title, sub, bg, ink, net) in enumerate(items):
    image = Image.new('RGB', (512, 512), bg)
    d = ImageDraw.Draw(image)
    d.rectangle((16, 16, 496, 496), outline=ink, width=5)
    center(d, '王家自选', 25, 40, ink, 512)
    d.line((55, 95, 457, 95), fill=ink, width=3)
    if index == 0:
        d.polygon([(256,115),(195,200),(181,228),(190,260),(218,279),(255,286),(292,279),(320,260),(329,228),(317,200)], fill=ink)
    elif index == 1:
        d.ellipse((174,124,319,267), outline=ink, width=9)
        d.line((200,254,291,141), fill=ink, width=9)
        d.line((225,220,190,177), fill=ink, width=6)
    elif index == 2:
        d.arc((154,138,358,254), 0, 180, fill=ink, width=12)
        d.line((152,193,360,193), fill=ink, width=8)
        for x in [210,256,300]:
            d.arc((x-15,115,x+15,177), 95, 280, fill=ink, width=5)
    else:
        for x,y in [(218,158),(281,170),(247,225)]:
            d.ellipse((x-28,y-19,x+28,y+19), fill=ink)
    center(d, title, 292, 70 if index != 1 else 64, ink, 512)
    center(d, sub, 388, 27, ink, 512)
    center(d, net, 445, 25, ink, 512)
    rng=random.Random(1420+index)
    for _ in range(12):
        x,y=rng.randint(25,480),rng.randint(25,480)
        d.line((x,y,min(x+20,487),y+2),fill=bg,width=2)
    atlas.paste(image,(index*512,0))
atlas.save(OUT/'chinese_packaging.png')

image=Image.new('RGB',(1280,320),'#843d34')
d=ImageDraw.Draw(image)
d.rectangle((10,10,1270,310),outline='#d6c59d',width=5)
center(d,'王家便利店',35,146,'#f2e4c1',1280)
center(d,'烟酒副食 · 日用百货',222,50,'#dfcba6',1280)
image.save(OUT/'shop_sign.png')

signs=[('收银台','请在此结账'),('饮料区','矿泉水 · 茶饮'),('零食区','罐头 · 面食 · 饼干'),('日用百货','日常所需'),('营业时间','早 7:00 — 晚 22:00'),('扫码付款','请向店员确认金额'),('今日特价','桶面 ¥4.50  水 ¥2.00'),('邻里小店','欢迎光临  谢谢惠顾')]
for i,(title,sub) in enumerate(signs):
    image=Image.new('RGB',(640,224),'#d9cfaf')
    d=ImageDraw.Draw(image)
    d.rectangle((8,8,632,216),outline='#8a4437',width=5)
    center(d,title,-18,132,'#803e32',640)
    center(d,sub,158,26,'#514f40',640)
    image.save(OUT/f'sign_{i}.png')
print('Original Chinese packaging and shop graphics built.')
