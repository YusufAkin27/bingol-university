# STITCH V3 KESFET2: Keşfet "blok blok" yönü

Kullanıcı referansı: iPhone çerçeveli 2 sütunlu masonry fotoğraf ızgarası. Karar: Keşfet 2 sütun masonry olur; sol altta yazar (avatar + ad), sağ altta beğeni; kutuya dokununca gönderi sayfası açılır, aşağı kaydırdıkça sıradaki gönderiler aynı detay düzeninde alt alta gelir. Mobil: kullanıcı A seçeneğini onayladı ve uygulandı (KESFET2-MB; ölçü tablosu `docs/design/BIREBIR_FEED.md` "Keşfet v2").

PNG'ler repoda değildir: `C:\bu_design\stitch\v3_kesfet2\` (`NN_ad_light.png` + `_dark.png`, 780x1688). Ayrıntılı şartname: `C:\bu_design\stitch\v3_kesfet2\SARTNAME.md`.

| Dosya | Ekran |
|---|---|
| 01_kesfet_masonry_A | Masonry, kutuda yalnız avatar+ad (sol alt) + kalp+sayı (sağ alt) (ÖNERİLEN) |
| 02_kesfet_masonry_B | Aynı + kutuda metin (en çok 2 satır) |
| 03_yukleniyor | Masonry iskeleti |
| 04_bos, 05_hata | Boş / hata |
| 06_cevrimdisi, 06b_bakim | Uyarı şeridi + eski gönderiler |
| 07_tanir_misin_seridi | Masonry'nin ilk 4 kutusundan sonra tam genişlik "Tanıyor Olabilirsin" bandı |
| 08_gonderi_sayfasi | Gönderi sayfası: yazar satırı, 4:5 foto, kalp+sayı+metin; altında sıradaki gönderi |
| 09_gonderi_kaydirilmis | Kaydırılmış: başlık kaybolur, geri düğmesi yüzen daire; sayfa sonu iskeleti |
| 10_cift_dokunus_begeni | Mevcut çift dokunuş (foto %15 kararır, 88 dp kalp) |

## Kararlar
- Kutu içi: A önerilir (kullanıcının tarifiyle birebir, foto örtülmez); B (metin de kutuda) hazır.
- Referanstan bilerek farklı: kategori çipleri yok (gönderide kategori yok; çip = Tümü/Popüler), zil/avatar/arama çubuğu yok (zil Ana Sayfa'da, profil alt barda, arama ayrı sayfa), alt bar mevcut cam hap (referanstaki "+" ve kalp sekmesi yok), pastel renkler ve kişi fotoğrafları yok (RENK-1).
- ⋯ menüsü kutuda yer almaz: uzun basma + gönderi sayfasındaki ⋯ (mevcut alt sayfa).
- Beğenilmiş kalp: kutuda dolu beyaz (foto üstü), gönderi sayfasında dolu pr (mevcut kurallar).
- Gönderi sayfası = aynı `Post` listesinden dikey akış (tıklanandan başlar, sonsuz kaydırma, geri dönünce masonry konumu korunur); geri düğmesi sabit, başlık kaybolur.

## Stitch notu
Stitch üretimi sunucu kotasına takıldı (`createSession RPC code=8`, 5 deneme). Ekranlar önceki Stitch v3 çıktılarının dili + RENK-1 token'larıyla Chrome headless'ta render edildi (`_render/gen.py`). Kota açılınca istem yeniden gönderilebilir.
