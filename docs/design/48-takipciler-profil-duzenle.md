# 48 - Takipçi listeleri, önerilen kişiler ve profili düzenleme

## Kapsam
- Envanter 92 `FollowListPage`, 93 `FollowSuggestionsPage`, 94 `EditProfilePage`, A53 değişiklikleri at onayı; profil fotoğrafı kırpma ve kaynak sheet'i `09-fotograf-kirpma.md`

## Istem
```text
Design 6 separate mobile screens (pushed pages, header with back arrow, no bottom nav).

1) Followers list. Header with name "Elif Yıldız", two tabs "Takipçiler 128" and "Takip edilenler 94" (Takipçiler selected). Search field "Takipçilerde ara". Rows: avatar, name, department, state text ("Seni takip ediyor", "Takipleşiyorsunuz", "Takiptesin") and a right button "Takip et" or "Takipte".

2) Following tab and empty states. "Takip edilenler" selected with search "Takip edilenlerde ara". Empty variants: "Henüz takipçi yok.", "Henüz kimse takip edilmiyor.", "Eşleşen kişi yok." Error row with "Yeniden dene".

3) Suggested people. Header "Önerilen kişiler". Rows with avatar, name, department, reason line, "Takip et" button; list loading skeleton. Empty: "Şimdilik önerilecek kişi yok." Hint text "Takip ettiklerinin gönderileri burada görünür."

4) Edit profile. Header "Profili düzenle". Avatar 96px with camera badge and link "Fotoğrafı değiştir". Fields: "Ad soyad", multiline "Hakkımda" (hint "Kendinizden kısaca bahsedin"), academic selects "Bölüm" and "Sınıf", read-only "Kurumsal e-posta" with lock icon and "ad.soyad@bingol.edu.tr", toggle "E-postamı diğer kullanıcılara göster". Sticky button "Kaydet".

5) Edit profile with errors and upload. Photo area showing "Yükleniyor…" with progress ring. Errors: "Ad en az 2 karakter olmalı.", "Bölümü seçin.", "Fotoğraf en fazla 2 MB olabilir. Daha küçük bir fotoğraf seçin.", "Yalnızca JPG, PNG veya WebP fotoğraflar yüklenebilir.", "Seçilen dosya okunamadı."

6) Discard changes dialog. Title "Değişiklikler kaydedilmedi", body "Çıkarsanız yaptığınız değişiklikler kaybolacak.", buttons "Düzenlemeye devam et" (primary) and "Vazgeç ve çık" (red text).
```

## Özellik kontrol listesi
- [ ] Takipçiler / Takip edilenler sekmeleri (sayaçlı), arama
- [ ] Satır durumu: Seni takip ediyor / Takipleşiyorsunuz / Takiptesin + Takip et / Takipte
- [ ] Boş, eşleşme yok, hata durumları
- [ ] Önerilen kişiler: liste, iskelet, boş
- [ ] Profili düzenle: avatar+değiştir, ad soyad, hakkımda, bölüm/sınıf, kurumsal e-posta (salt okunur), e-posta göster anahtarı, Kaydet
- [ ] Yükleniyor, boyut/biçim hataları, doğrulama hataları
- [ ] Değişiklikleri at diyaloğu

## Dikkat
- E-posta düzenlenemez; telefon, doğum günü, cinsiyet, sosyal medya bağlantıları alanı yok.
- Kullanıcı adı (@handle) alanı yok.
