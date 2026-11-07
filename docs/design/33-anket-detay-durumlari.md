# 33 - Anket detayı: sonuç ve engel durumları

## Kapsam
- Envanter 66 `PollDetailPage` durumları: oy verildi/sonuçlar, sonuçlar gizli, kapandı, henüz açılmadı, yetki yok, bayat veri, A34 oyu geri çekme

## Istem
```text
Design 6 separate mobile screens of the poll detail page (header "Anket"/"Sonuçlar", back arrow, no bottom nav).

1) Voted, results visible. Header "Sonuçlar". Green pill "Oy verdiniz". Option rows as horizontal bars with percentage and votes: "Mercimek çorbası 46% · 58 oy" (my choice with soft-red tint and badge "Seçiminiz"), "Ezogelin 31% · 39 oy", "Domates çorbası 23% · 29 oy". Footer "126 katılım". Secure note "Oyunuz gizli. Seçiminizi yalnızca siz görürsünüz; yöneticiler dahil kimse kimin ne seçtiğini göremez." Buttons "Oyu değiştir" and text "Oyu geri çek".

2) Results hidden until close. Voted state with the eye-off notice card "Sonuçlar anket kapanınca görünecek." and badge "Oy verdiniz". No bars.

3) Closed poll with final results. Grey pill "Kapandı", subtitle "Sona erdi". Bars with winning option highlighted, "128 katılım". No vote buttons. For a rating poll variant show "Puanlama özeti": average "4,2" with stars and "86 puan".

4) Not open yet. Info card with clock icon: "Bu anket henüz açılmadı." Options listed disabled grey, button disabled.

5) Cannot vote. Card with lock icon: "Bu ankete katılma yetkiniz yok." Second card variant: "Oyunuz kaydedildi; bu ankette oy değiştirilemez." Third: "Bu anket kapandı. Oy verilemez."

6) Retract vote dialog and stale data. Dialog title "Oyu geri çek", body "Oyunuz silinecek. Devam edilsin mi?", buttons "Vazgeç" and "Geri çek" (red). Above, an amber stale banner "Güncellenemedi; son bilinen veri gösteriliyor." and a snackbar "Oyunuz geri çekildi."
```

## Özellik kontrol listesi
- [ ] Sonuç çubukları (yüzde, oy sayısı), "Seçiminiz" rozeti, katılım sayısı
- [ ] Gizli oy notu
- [ ] Sonuçlar kapanınca görünecek durumu
- [ ] Kapandı + Sona erdi; puanlama özeti
- [ ] Henüz açılmadı; yetki yok; oy değiştirilemez; kapandı oy verilemez
- [ ] Oyu değiştir / Oyu geri çek + onay diyaloğu
- [ ] Bayat veri bandı

## Dikkat
- Kim hangi seçeneğe oy verdi listesi YOK (gizli oy, kimlik hiçbir uçta gösterilmez).
- Oy verenlerin avatarları gösterilmesin.
