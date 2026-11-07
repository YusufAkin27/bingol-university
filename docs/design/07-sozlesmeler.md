# 07 - Sözleşmeler ve yeniden onay

## Kapsam
- Envanter 15 `LegalReacceptGate`, 16 `LegalReacceptPage`, 17 `LegalListPage`, 18 `LegalDocPage`, alt sayfa A2 ("Kabul etmiyorum" seçenekleri)

## Istem
```text
Design 6 separate mobile screens (no bottom nav).

1) Legal re-accept, mandatory (cannot be skipped). Title "Sözleşmeler güncellendi", intro "Kullanım koşulları ve gizlilik metinlerinde değişiklik yaptık. Uygulamayı kullanmaya devam etmek için güncellenen belgeleri okuyup kabul etmeniz gerekiyor." Section "Güncellenen belgeler": four tappable rows with chevron: "Kullanım Koşulları - Sürüm 3 · 12 Ekim 2026", "Gizlilik Politikası", "KVKK Aydınlatma Metni", "Topluluk Kuralları". Small note "İsteğe bağlı açık rıza izinleri bu onaydan ayrıdır; bu işlemle verilmiş sayılmaz." Checkbox "Güncellenen belgeleri okudum ve kabul ediyorum". Primary button "Kabul et" (disabled until checked), text button "Kabul etmiyorum".

2) Legal re-accept, soft (can be postponed). Same layout, intro "Bazı belgelerin yeni sürümü yayımlandı. Şimdi inceleyip kabul edebilir ya da daha sonraya bırakabilirsiniz; ilerleyen günlerde kabul etmeniz gerekecek." Checkbox checked. Buttons "Kabul et", "Daha sonra", "Kabul etmiyorum". At top an amber banner: "Belgeler yeniden güncellendi. Lütfen yeni sürümleri inceleyip tekrar kabul edin."

3) Decline bottom sheet over dimmed screen 1. Title "Kabul etmeden devam edilemez", body "Güncel sözleşmeleri kabul etmezseniz uygulamayı kullanamazsınız. Hesabınızı silebilir ya da çıkış yapıp daha sonra tekrar karar verebilirsiniz." Buttons: "Hesabımı sil" (danger), "Çıkış yap" (outline).

4) Legal documents list (from Settings > Sözleşmeler). Header "Sözleşmeler". Grouped card list, each row icon + title + "Sürüm 3 · 12 Ekim 2026": "Kullanım Koşulları", "Gizlilik Politikası", "KVKK Aydınlatma Metni", "Topluluk Kuralları". Chevron on each.

5) Legal document reader. Header "Kullanım Koşulları", subtitle "Sürüm 3 · Yürürlük: 12 Ekim 2026". Long markdown body: H2 headings, numbered clauses, bullet lists, bold terms. Realistic Turkish legal-style placeholder text about using the app (membership, content rules, account closure).

6) Legal list empty/error variant. Header "Sözleşmeler", centered illustration, text "Yayımlanmış sözleşme yok." and below a separate error row "Yüklenemedi, tekrar dene" with a "Yeniden dene" button.
```

## Özellik kontrol listesi
- [ ] Zorunlu yeniden onay: belge listesi (sürüm+tarih), onay kutusu, Kabul et (pasif/aktif), Kabul etmiyorum
- [ ] Atlanabilir sürüm: Daha sonra düğmesi + güncellenmiş bandı
- [ ] Açık rıza ayrı olduğu notu
- [ ] "Kabul etmiyorum" sheet: Hesabımı sil, Çıkış yap
- [ ] Sözleşme listesi (4 tür, sürüm · tarih)
- [ ] Sözleşme okuyucu (markdown: başlık, numaralı madde, liste, kalın)
- [ ] Boş liste ve yükleme hatası

## Dikkat
- Hukuk metni gerçek bir kanun/madde numarası uydurmasın; yer tutucu cümleler olsun.
- Belge türleri yalnız: Kullanım Koşulları, Gizlilik Politikası, KVKK Aydınlatma Metni, Topluluk Kuralları.
- Dil seçici (EN/AR sözleşme) yok; sözleşmeler Türkçe sunulur.
