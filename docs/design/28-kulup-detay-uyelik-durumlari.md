# 28 - Kulüp detayı: üyelik ve rol varyantları

## Kapsam
- Envanter 58 `ClubDetailPage` (referans: standart görünüm). Bu istem: üye değil (serbest/onaylı), bekleyen, üye, yönetici, yasaklı/gizli varyantları

## Istem
```text
Design 6 separate mobile screens of the same club detail page for different viewers (no bottom nav; transparent app bar over the cover with back arrow and "⋯"). Common layout: cover image, round club logo, club name "Robotik Kulübü", category chip, "86 üye" and visibility chip ("Herkese açık" or "Özel"), description, then tab bar "Gönderiler | Etkinlikler | Üyeler | Anketler".

1) Visitor, open club. Main button "Katıl" (primary). Tabs visible with content (public).

2) Visitor, approval-required club. Main button "Katılma isteği gönder". Private club chip "Özel".

3) Request pending. Disabled-looking tonal pill "İstek gönderildi" with a text button "Geri çek". Tab content limited.

4) Member. Pill "Üyesin" with check, a second button "Kulüp sohbeti" (chat bubble icon). In the "Gönderiler" tab a composer card at top: avatar, field "Kulübe bir şeyler yaz", buttons "Görsel ekle" and "Paylaş". Pinned post card with label "Sabit". Under "Etkinlikler" an upcoming-events empty text "Bu kulübün yaklaşan etkinliği yok."

5) Club manager/owner. Amber banner on top "3 bekleyen katılma isteği" with arrow. The "⋯" menu opened as a dropdown: "Kulübü düzenle", "Başvurular (3)", "Üyeleri yönet", "Kapağı değiştir", "Kulübü sil" (red); for non-owner moderators the list is shorter. In "Anketler" tab a button "Anket oluştur". Role chip "Yönetici" next to the name.

6) Banned or unavailable. Main button replaced by grey disabled "Katılamazsın". Another small card for an unavailable club: "Kulüp şu an kullanılamıyor." For the member's "⋯" menu show rows "Kulübü şikâyet et" and "Kulüpten ayrıl" (red).
```

## Özellik kontrol listesi
- [ ] Katıl (serbest), Katılma isteği gönder (onaylı), İstek gönderildi + Geri çek, Üyesin, Katılamazsın
- [ ] Görünürlük etiketi (Herkese açık / Özel), üye sayısı, kategori
- [ ] Sekmeler: Gönderiler, Etkinlikler, Üyeler, Anketler (+ yöneticiye Anket oluştur)
- [ ] Üye: Kulüp sohbeti düğmesi, gönderi yazma kartı (Görsel ekle, Paylaş), Sabit etiketi
- [ ] Yönetici: bekleyen istek bandı, ⋯ menüsü (Kulübü düzenle, Başvurular, Üyeleri yönet, Kapağı değiştir, Kulübü sil), rol etiketi
- [ ] Üye ⋯ menüsü: Kulübü şikâyet et, Kulüpten ayrıl
- [ ] Kulüp kullanılamıyor durumu

## Dikkat
- Kulüp sayfasındaki gönderi (görsel + yazı) Keşfet gönderisinden ayrıdır; yine de yorum alanı/sayacı yok.
- Aidat/ödeme, "Kulübe bağış yap" yok.
- Etkinlikler her zaman bu kulübe aittir; "Düzenleyen: Robotik Kulübü".
