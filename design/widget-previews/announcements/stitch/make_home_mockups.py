import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np
slug=sys.argv[1]
R='C:/bu_dsg/wid/design/widget-previews/'+slug+'/'
K=3
def font(sz,w='segoeui.ttf'):
    return ImageFont.truetype('C:/Windows/Fonts/'+w, int(sz*K))
def wallpaper(w,h,theme,plat):
    y,x=np.mgrid[0:h,0:w].astype(float); y/=h; x/=w
    if theme=='dark':
        a=np.array([14,16,28]);b=np.array([40,44,66]);c=np.array([8,8,10])
        g=(1-y)[...,None]*0+0
        t=np.clip(0.55*np.exp(-(((x-.75)**2)/.12+((y-.18)**2)/.08))+0.35*np.exp(-(((x-.2)**2)/.15+((y-.85)**2)/.1)),0,1)[...,None]
        img=c*(1-t)+(b if plat=='ios' else np.array([30,52,58]))*t+ a*0.2
    else:
        c=np.array([236,236,240]);b=np.array([255,214,200]) if plat=='ios' else np.array([205,226,236])
        t=np.clip(0.8*np.exp(-(((x-.8)**2)/.12+((y-.15)**2)/.09))+0.5*np.exp(-(((x-.15)**2)/.2+((y-.9)**2)/.12)),0,1)[...,None]
        img=c*(1-t)+b*t
    return Image.fromarray(np.clip(img,0,255).astype('uint8')).convert('RGBA')
def rr_mask(w,h,r):
    m=Image.new('L',(w,h),0);ImageDraw.Draw(m).rounded_rectangle((0,0,w-1,h-1),r,fill=255);return m
def shadow(base,im,pos,theme,blur=18,off=8,op=90 ):
    a=im.split()[3]
    s=Image.new('RGBA',base.size,(0,0,0,0))
    sh=Image.new('RGBA',im.size,(0,0,0,op if theme=='dark' else 45)); sh.putalpha(a.point(lambda v:v*op//255 if theme=='dark' else v*45//255))
    s.paste(sh,(pos[0],pos[1]+off*K),sh); s=s.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(s); base.alpha_composite(im,pos)
def status(d,W,theme,plat):
    col=(255,255,255) if theme=='dark' else (10,10,12)
    if plat=='ios':
        d.text((52*K,19*K),'9:41',font=font(16,'segoeuib.ttf'),fill=col)
        x=W-62*K
        for i in range(4): d.rounded_rectangle((x-70*K+i*5*K,(33-3*i)*K-0,x-70*K+i*5*K+3*K,38*K),K,fill=col)
        d.rounded_rectangle((W-52*K,25*K,W-26*K,37*K),3*K,outline=col,width=K); d.rounded_rectangle((W-50*K,27*K,W-36*K,35*K),2*K,fill=col)
    else:
        d.text((28*K,12*K),'9:41',font=font(14),fill=col)
        d.rounded_rectangle((W-48*K,18*K,W-30*K,28*K),2*K,outline=col,width=K);d.rounded_rectangle((W-46*K,20*K,W-38*K,26*K),K,fill=col)
        d.polygon([(W-70*K,28*K),(W-58*K,28*K),(W-58*K,16*K)],fill=col)
def build(plat,theme):
    t=theme
    if plat=='ios':
        W,H=393*K,852*K; rad=55*K
        wid=lambda n:Image.open(R+f'ios-{n}-{t}.png').convert('RGBA')
        sm,md,lg=wid('small'),wid('medium'),wid('large')
        scr=wallpaper(W,H,t,plat); d=ImageDraw.Draw(scr); status(d,W,t,plat)
        x0=(W-338*K)//2; y=92*K; gap=22*K
        shadow(scr,sm,(x0,y),t); shadow(scr,sm,(x0+180*K,y),t); y+=158*K+gap
        shadow(scr,md,(x0,y),t); y+=158*K+gap
        shadow(scr,lg,(x0,y),t)
        di=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(di).rounded_rectangle((W//2-62*K,11*K,W//2+62*K,48*K),18*K,fill=(0,0,0,255)); scr.alpha_composite(di)
    else:
        W,H=412*K,915*K; rad=36*K
        wid=lambda n:Image.open(R+f'android-{n}-{t}.png').convert('RGBA')
        s22,w42,w44=wid('2x2'),wid('4x2'),wid('4x4')
        scr=wallpaper(W,H,t,plat); d=ImageDraw.Draw(scr); status(d,W,t,plat)
        x0=(W-350*K)//2; y=64*K; gap=14*K
        shadow(scr,w42,(x0,y),t); y+=170*K+gap
        shadow(scr,s22,(x0,y),t); shadow(scr,s22,(x0+180*K,y),t); y+=170*K+gap
        shadow(scr,w44,(x0,y),t)
        d=ImageDraw.Draw(scr); d.ellipse((W//2-9*K,16*K,W//2+9*K,34*K),fill=(0,0,0))
        d.rounded_rectangle((W//2-60*K,H-14*K,W//2+60*K,H-10*K),2*K,fill=(255,255,255) if t=='dark' else (20,20,20))
    scr.putalpha(rr_mask(W,H,rad))
    bz=12*K; FW,FH=W+2*bz,H+2*bz
    out=Image.new('RGBA',(FW+80*K,FH+80*K),(0,0,0,0))
    frame=Image.new('RGBA',(FW,FH),(0,0,0,0));fd=ImageDraw.Draw(frame)
    fd.rounded_rectangle((0,0,FW-1,FH-1),rad+bz,fill=(24,24,26,255) if t=='dark' else (58,58,62,255),outline=(70,70,74,255),width=K)
    frame.alpha_composite(scr,(bz,bz))
    bg=Image.new('RGBA',out.size,(14,14,16,255) if t=='dark' else (222,222,226,255))
    shadow(bg,frame,(40*K,40*K),t,blur=40,off=14,op=140)
    bg.convert('RGB').save(R+f'home-{plat}-{t}.png')
for p in ['ios','android']:
    for t in ['light','dark']: build(p,t)
