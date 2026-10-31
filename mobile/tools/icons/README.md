# BuIcons araç hattı (Hugeicons -> yazı tipi)

Uygulama ikonları Lucide yerine **Hugeicons 4.4.0** (MIT) glif verisinden üretilmiş kendi yazı tipimizdir:
`mobile/assets/fonts/BuIcons.ttf` + `mobile/lib/core/icons/bu_icons.dart` (`BuIcons.<anlamsal ad>`).
Uygulama çalışma zamanında `hugeicons` paketini ya da SVG ayrıştırmasını **kullanmaz**; `Icon(BuIcons.home)`
Lucide ile aynı maliyetlidir (statik glif, `IconData`, ağaç budaması çalışır). Gerekçe ve karar: `docs/design/IKON_HUGEICONS.md` "Uygulama kararı".

## Dosyalar

| Dosya | Görev | Çıktı |
|---|---|---|
| `parse_doc_map.py` | `docs/design/IKON_HUGEICONS.md` bölüm 6 eşlemesini okur, Material adlarını ve dolu glif listesini ekler | `icon_map.json` |
| `extract_hugeicons.py` | pub.dev'den `hugeicons-4.4.0` indirir, yalnız kullanılan ~166 ikonun SVG verisini çıkarır | `hugeicons_subset.json` |
| `bu_icon_lib.py` | SVG öğesi -> dolu kontur (skia-pathops), dolu glif tarifleri (`FILLED_RECIPES`), referans SVG | (kütüphane) |
| `build_icons.py` | glifleri birleştirir, TTF + Dart sabitlerini yazar | `BuIcons.ttf`, `bu_icons.dart`, `icon_codepoints.json` |
| `verify_icons.py` | bağımsız referans (resvg) ile piksel karşılaştırması + kontrol tahtaları | `work/verify_report.json`, `migrate_kontrol_*.png` |
| `migrate_usages.py` | 2. faz: `LucideIcons.*`/`Icons.*` -> `BuIcons.*` (`--dry-run` / `--apply`) | rapor |

`icon_map.json`, `hugeicons_subset.json`, `icon_codepoints.json` repoda tutulur (ağ gerekmeden yeniden üretim).
`icon_codepoints.json` yalnız eklemelidir: bir ad bir kez kod noktası alır, sonra değişmez (yeni ad = sonraki boş nokta).

## Yeniden üretim (repo kökünden)

```bash
pip install skia-pathops fonttools pillow numpy      # bir kez
python -I -X utf8 mobile/tools/icons/parse_doc_map.py        # belge/eşleme değiştiyse
python -I -X utf8 mobile/tools/icons/extract_hugeicons.py    # yeni Hugeicons adı eklendiyse (ağ gerekir)
python -I -X utf8 mobile/tools/icons/build_icons.py          # font + bu_icons.dart (yeniden üretilebilir)
# doğrulama (resvg bir kez): cd mobile/tools/icons && npm install --no-package-lock
python -I -X utf8 mobile/tools/icons/verify_icons.py --boards C:/bu_design/icons
```

Yeni ikon eklemek: `docs/design/IKON_HUGEICONS.md` bölüm 6 tablosuna satır ekleyin (ya da `parse_doc_map.py`
içine ek eşleme), `parse_doc_map.py` -> `extract_hugeicons.py` -> `build_icons.py`. Üretilen dosyaları elle düzenlemeyin.

## Yöntem

1. Her SVG öğesi (path/circle/rect) skia-pathops ile **stroke 1.75, öğenin kendi cap/join'i** ile dolu konturlara çevrilir.
   Alt yollar ayrı stroke edilir (Skia PathOps, çok alt yollu tek stroke çıktısını birleştirirken parça kaybedebiliyor).
2. Konturlar birleştirilir (union), y ekseni çevrilir, kübik -> kuadratik (cu2qu, 0.006 px hata), dış kontur saat yönünde.
3. TrueType: `unitsPerEm` 2400 (24 px ızgara x100), ascent = em, descent = 0; böylece `Icon` kutusunda SVG ile birebir konumlanır (Lucide de aynı düzen).
4. Dolu hâller (`<ad>Filled`): kapalı öğeler doldurulur (+çizgisi), iç ayrıntı (tik, ünlem, noktalar, pusula ibresi) dolgudan oyulur.
   Tarifler `bu_icon_lib.FILLED_RECIPES` içindedir.
5. Karşılığı olmayan iki ikon (`delete`, `keyboard`) `BuIcons` içinde `LucideIcons.*`'e işaret eder.

`--scale` (build_icons.py) tüm glifleri merkezden ölçekler; varsayılan 1.0 (karar: belge "Uygulama kararı").

## Lisans

Glif şekilleri Hugeicons 4.4.0 (MIT, Copyright (c) 2024 Halal Labs / Hugeicons) verisinden türetilmiştir. MIT metni:
`mobile/assets/licenses/hugeicons-MIT.txt`; uygulamada `registerBuIconLicenses()` (`lib/core/icons/bu_icon_licenses.dart`,
2. fazda `main()` içinden çağrılır) ile Flutter lisans sayfasına eklenir.
