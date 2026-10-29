# 37 - Etkinlik listesi: yükleniyor/boş/hata ve onay diyalogları

## Kapsam
- Envanter 72 `EventsPage` durumları, A36 listeden vazgeç/ayrıl onayı, A42 "Etkinliğiniz incelemede" diyaloğu, etkinlik iptal ve katılımdan ayrılma onayları

## Istem
```text
Design 6 separate mobile screens of the Etkinlikler page and its dialogs (pushed page, header "Etkinlikler" with back arrow, segmented "Keşfet | Etkinliklerim | Oluşturduklarım", no bottom nav).

1) Loading. Calendar card skeleton (grey rounded block with grey day circles) and three grey event card skeletons below; text "Yükleniyor" small and shimmer.

2) Empty states in three blocks: "Etkinliklerim - Yaklaşan": "Katılacağın bir etkinlik yok."; "Oluşturduklarım": "Henüz bir etkinlik oluşturmadın."; and the can't-create case card: title "Etkinlik oluşturmak için bir kulübün yöneticisi olmalısın", body "Etkinlikler kulüpler adına açılır. Bir kulübün yöneticisi olduğunda burada etkinlik oluşturabilirsin.", button "Kulüplere göz at".

3) Error and offline. Strip "İnternet bağlantısı yok · Kayıtlı veriler gösteriliyor"; card "Yüklenemedi, tekrar dene" with "Yeniden dene"; toast "Bu etkinliğin kayıtları kapalı." as a registration-closed error example.

4) Leave event dialog. Title "Katılımdan ayrıl", body "Bu etkinlik Etkinliklerim listenden çıkarılacak.", buttons "Vazgeç" and "Ayrıl" (red). Success toast under it: "Katılımdan ayrıldın."

5) Cancel event dialog (organizer). Title "Etkinliği iptal et", body "Bu etkinlik tüm katılımcılar için iptal edilecek.", buttons "Vazgeç" and "İptal et" (red). Toast examples: "Etkinlik iptal edildi.", "Kayıtlar kapatıldı.", "Kayıtlar yeniden açıldı."

6) Event under review dialog (after creating). Illustration with check and clock, title "Onaya gönderildi", body "Etkinliğin admin onayından sonra yayınlanacak. Durumunu Oluşturduklarım sekmesinden takip edebilirsin.", button "Tamam".
```

## Özellik kontrol listesi
- [ ] Yükleniyor iskeleti
- [ ] Boş durumlar (Yaklaşan, Oluşturduklarım) ve "kulübün yöneticisi olmalısın" kartı + Kulüplere göz at
- [ ] Hata, çevrimdışı şeridi, kayıtlar kapalı hatası
- [ ] Katılımdan ayrıl onayı + bildirim
- [ ] Etkinliği iptal et onayı + bildirimler
- [ ] Onaya gönderildi diyaloğu

## Dikkat
- Etkinlik oluşturma kulüpsüz kullanıcıya açılmaz; "Bireysel etkinlik" seçeneği yok.
- İptal diyaloğu "katılımcılara bildirim gider" dışında vaat içermez.
