# STITCH V3 - HOME grubu (özet)

Kapsam: Ana Sayfa + özelleştirme, Yemek, Bildirimler + tercihler, Haber (liste/detay/favoriler), Arama.
Çıktı (repo dışı): `C:\bu_design\stitch\v3_home\` (`1_ana_sayfa` ... `5_arama`, `SARTNAME.md`, `_kaynak_html` = Stitch'in tam ölçülü `code.html` dosyaları).

## Yöntem (STITCH-OPEN'dan farklı noktalar)
- Her kategori için AYRI Stitch projesi, istemler aynı oturumda paralel gönderilir (projeler birbirini beklemez); üretim ~5-8 dk.
- Dışa aktarma: tuvale tıkla, Ctrl+A, Export -> `.zip` (iframe içinde `getByText('.zip')` + `getByRole('button',{name:'Export'})`), indirme `download.saveAs` ile alınır. Zip her ekran için `screen.png` + `code.html` (Tailwind, px = dp) verir; ölçüler buradan okunur.
- Stitch'in yaygın hataları (bu grupta görüldü): sahte İngilizce üst çubuk + kırmızı avatar ("Cafeteria Menu Detail"), lavanta zemin ve koyu kırmızı, pembe uyarı bandı, uydurma içerik ("Ücretsiz", "14 yorum", bilgi kutuları). Düzeltme turu: tüm ekranlar seçilip (Ctrl+A) tek istemle düzeltilir.

## Durum
Ana Sayfa + özelleştirme: TAMAM (HOME Flutter ajanına teslim edildi). Yemek, Bildirimler, Haber, Arama: taslak üretildi, düzeltme turu bekliyor; ayrıntı SARTNAME.md.

## Ana kararlar (Ana Sayfa)
Kırmızı dolu menü vitrini, logo karosu, avatar ve renkli ikon blobları kalktı; "Bugün" tek bakış yüzeyi + "Bugünkü dersler" eklendi; tek yüzey ailesi (beyaz + 1 dp çerçeve, gölge yok); başlıkta kalem (Ana sayfayı düzenle) ve zil; düzenleme: tutamaç + yukarı/aşağı düğmeleri + anahtar + "Varsayılana dön" + "Bitti"; Hızlı erişim seçici 5 slot (11 havuz); hepsi gizliyken "Ana sayfan boş" + "Bölüm ekle".
