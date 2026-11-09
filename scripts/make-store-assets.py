# -*- coding: utf-8 -*-
"""Magaza gorselleri: ChatGPT'nin urettigi telefon cerceveli goruntuler (<GPT>/<dil>_<ekran>.png; ekran icerigi mobile/test/store/
store_assets_shots_test.dart ham render'indan, gercek uygulama) -> docs/store-assets/<play|ios|ios-1290x2796>/<dil>/NN_ad.png.
GPT varsayilan C:/bu_store/gpt (env STORE_GPT). ChatGPT cikti boyutu degisir (852x1847, 794x1981...): oran bozulmaz; yukseklige
sigdirilir, yanlar kenar rengi cogaltilip hafif bulaniklastirilarak doldurulur, sonra hedef boyuta Lanczos ile olceklenir.
Calistirma: python -I -X utf8 scripts/make-store-assets.py"""
import os, pathlib
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
GPT = pathlib.Path(os.environ.get("STORE_GPT", "C:/bu_store/gpt"))
OUT = ROOT / "docs/store-assets"
# Magaza sirasi: ilk 3 en cok gorulur (ana sayfa, Kesfet, yemek)
ORDER = ["home", "discover", "menu", "events", "news", "clubs", "profile"]
TARGETS = {"play": (1080, 1920), "ios": (1179, 2556), "ios-1290x2796": (1290, 2796)}


def fit(img, w, h):
    iw, ih = img.size
    s = h / ih
    nw = round(iw * s)
    body = img.resize((nw, h), Image.LANCZOS)
    if nw >= w:  # cok genis: ortadan kirp
        x = (nw - w) // 2
        return body.crop((x, 0, x + w, h))
    canvas = Image.new("RGB", (w, h))
    pad = (w - nw) // 2
    # sol/sag kenar sutunu cogaltilir (dikey degrade korunur), hafif bulaniklastirilir
    left = body.crop((0, 0, 1, h)).resize((pad + 2, h))
    right = body.crop((nw - 1, 0, nw, h)).resize((w - pad - nw + 2, h))
    canvas.paste(left, (0, 0))
    canvas.paste(right, (pad + nw - 2, 0))
    canvas = canvas.filter(ImageFilter.GaussianBlur(2))
    canvas.paste(body, (pad, 0))
    return canvas


def main():
    for store, (w, h) in TARGETS.items():
        for lang in ("tr", "en", "ar"):
            d = OUT / store / lang
            d.mkdir(parents=True, exist_ok=True)
            for old in d.glob("*.png"):
                old.unlink()
            for i, key in enumerate(ORDER, 1):
                src = GPT / f"{lang}_{key}.png"
                if not src.exists():
                    print("YOK", src)
                    continue
                out = d / f"{i:02d}_{key}.png"
                fit(Image.open(src).convert("RGB"), w, h).save(out, optimize=True)
                print(out)


main()
