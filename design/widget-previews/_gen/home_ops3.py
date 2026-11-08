# Ana ekran maketleri (Pillow): python -I -X utf8 home_ops3.py
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
B=os.path.dirname(os.path.abspath(__file__))+'/../'
S=3; W,H=390*S,844*S
FONT=B+'../../mobile/assets/fonts/Inter-Regular.ttf'
def grad(c1,c2,c3):
    im=Image.new('RGB',(W,H));px=im.load()
    for y in range(H):
        t=y/H
        for x in range(0,W):
            u=(t*0.8+x/W*0.2)
            if u<.5: a,b,k=c1,c2,u*2
            else: a,b,k=c2,c3,(u-.5)*2
            px[x,y]=tuple(int(a[i]+(b[i]-a[i])*k) for i in range(3))
    return im
WALL={'light':((226,228,236),(196,200,214),(236,226,230)),'dark':((24,26,34),(10,10,14),(30,24,34))}
def shadow(base,im,pos):
    sh=Image.new('RGBA',base.size,(0,0,0,0));m=Image.new('RGBA',im.size,(0,0,0,70))
    sh.paste(m,(pos[0],pos[1]+10*S),im.split()[3]);sh=sh.filter(ImageFilter.GaussianBlur(14*S))
    base.alpha_composite(sh)
def status(d,th,ios):
    f=ImageFont.truetype(FONT,(15 if ios else 13)*S);col=(255,255,255) if th=='dark' else (10,10,12)
    d.text(((34 if ios else 24)*S,(16 if ios else 12)*S),'9.41' if ios else '09:41',font=f,fill=col)
    x=W-(30 if ios else 24)*S
    d.rounded_rectangle((x-24*S,(18 if ios else 14)*S,x,(28 if ios else 24)*S),3*S,outline=col,width=S)
def make(plat,th,slug):
    base=grad(*WALL[th]).convert('RGBA');d=ImageDraw.Draw(base);ios=plat=='ios'
    status(d,th,ios)
    if ios:
        L=lambda n:Image.open(f'{B}{slug}/ios-{n}-{th}.png').convert('RGBA')
        s,m=L('small'),L('medium');g=int(16*S)
        x0=(W-m.width)//2
        y=int(130*S)
        base2=[(m,(x0,y)),(s,(x0,y+m.height+g)),(s,(x0+s.width+(m.width-2*s.width),y+m.height+g))]
    else:
        L=lambda n:Image.open(f'{B}{slug}/android-{n}-{th}.png').convert('RGBA')
        s,m,l=L('2x2'),L('4x2'),L('4x4');g=int(10*S)
        x0=(W-m.width)//2;y=int(120*S)
        base2=[(m,(x0,y)),(s,(x0,y+m.height+g)),(s,(x0+m.width-s.width,y+m.height+g))]
    for im,p in base2: shadow(base,im,p)
    for im,p in base2: base.alpha_composite(im,p)
    # home gostergesi / gezinme cizgisi
    d=ImageDraw.Draw(base);col=(255,255,255,150) if th=='dark' else (0,0,0,120)
    d.rounded_rectangle((W//2-70*S,H-14*S,W//2+70*S,H-10*S),2*S,fill=col)
    out=base.convert('RGB')
    # iPhone cercevesi
    if ios:
        fr=Image.new('RGB',(W+40,H+40),(8,8,10));fr.paste(out,(20,20))
        mask=Image.new('L',fr.size,0);ImageDraw.Draw(mask).rounded_rectangle((0,0)+fr.size,60*S,fill=255)
        o=Image.new('RGBA',fr.size,(0,0,0,0));o.paste(fr,(0,0),mask);o.save(f'{B}{slug}/home-ios-{th}.png')
    else:
        out.save(f'{B}{slug}/home-android-{th}.png')
for slug in ['poll','quickaccess','social']:
    for plat in ['ios','android']:
        for th in ['light','dark']: make(plat,th,slug)
