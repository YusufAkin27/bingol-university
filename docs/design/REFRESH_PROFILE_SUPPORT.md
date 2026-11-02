# Profil ve destek ekran yenilemesi

Referans: HOME_REFERENCE_2026_11_02.md. Çalışma kopyası: C:/bu_refresh_profile, temel commit 5abea8d4.

## Uygulanan tasarım

- Profilim: ikonlu kompakt başlık; kimlik/biyografi 24 dp köşeli beyaz, hafif gölgeli kartta; içerik ve tercih menülerinde anlamlı çizgi ikonları.
- Ayarlar: responsive ortak başlık, 22 dp yuvarlak kategori kartları ve pastel marka ikon karoları. Dil/tema, sohbet, bildirim ve güvenlik hedefleri aynı.
- Profil alt sayfaları: ortak geri başlığı, 22 dp kart grupları ve hizalı ayırıcılar. Güvenlik/veri satırlarında anlamlı ikonlar; sözleşme listesinde belge ikonlu kartlar.
- Kişisel kulüp ve etkinlik kartları: hafif yükseltilmiş yüzey.
- Bildirim tercihleri: yalnız _PrefCard görsel yüzeyi değişti; tercih alanları, varsayılanlar, kaydetme ve sessiz saat davranışı değiştirilmedi.
- Destek: SSS ve talep listesi ayrı yuvarlak beyaz kartlar; ikonlu bölüm başlıkları; öneri listesinde aynı kart ailesi; kullanıcı destek mesajında yumuşak marka tonu.
- Form doğrulaması, onay diyalogları, durum/gizlilik kararları ve API istekleri korunur. Yeni paket veya çeviri eklenmedi.

## Ekran inceleme listesi

| Alan | Ekranlar | Sonuç |
|---|---|---|
| Profil | ProfileTab, SettingsPage | Başlık, kimlik ve menü grupları yenilendi |
| Profil düzenleme | EditProfilePage | Yeni ortak profil başlığı; mevcut düzenli form ve avatar akışı korundu |
| Güvenlik/veri | AccountSecurityPage, PrivacyDataPage, MyDataPage, DeleteAccountPage, BlockedUsersPage | Yeni ortak başlık/kart grupları; işlem ve doğrulama davranışları korundu |
| Bildirim | NotificationPrefsPage | Yalnız tercih kartı yüzeyi yenilendi |
| Kişisel içerik | MyClubsPage, MyEventsPage, SavedNewsPage | Kart yüzeyleri ve kayıtlı haberler başlığı yenilendi |
| Hukuk | LegalListPage, LegalDocPage | Liste belge kartları yenilendi; detayın mevcut okuma düzeni korundu |
| Diğer kullanıcı | UserProfilePage | İncelendi; mevcut 24 dp gölgeli kartları, avatar/kimlik ve gizli profil blokları yeni referansa uygun olduğu için korundu |
| Destek | SupportPage, SupportTicketPage, SuggestionsPage | Liste/bölüm/kart ve konuşma yüzeyleri yenilendi |
| Destek formları | NewTicketPage, FeedbackPage | İncelendi; mevcut 20 dp kenarlı Material formu, hata/sayaç/durum bileşenleri korundu; ortak boş durum kartı yenilendi |
| Öneri detayı | SuggestionDetailPage | İncelendi; mevcut form ve oy etkileşimi korundu, ortak destek yüzeyleriyle uyumlu |

Toplam: 15 profil ve 6 destek sayfası incelendi. Korundu yazan sayfalara sırf dosya değişsin diye davranış değişikliği yapılmadı.

## Doğrulama

- dart analyze lib/features/profile lib/features/support: temiz.
- profil1, profil2, profilyard, profil_rows_layout, user_profile, destek: 130 test geçti.
- redesign/k8_support_test ve redesign/p13_test: 37 test geçti (form gövdeleri, talep kapatma onayı, yanıt, oy verme, 429, loading/hata ve dil/ölçek durumları dahil).
- p3_profile_shots: 24 açık/koyu profil görüntüsü; son Profilim/Ayarlar için 6 açık/koyu/1.3x görüntüsü geçti.
- k8_support_shots: 7 açık ve 4 koyu destek görüntüsü geçti.
- Temsili gerçek görüntüler görsel incelendi: Profilim açık, Ayarlar koyu, Destek açık. Kaynak veriler test verisidir.

Yerel görsel çıktıları (commitlenmez): test-results/shots/profile/, profile-final/, support/, support-dark/. Ana kanıtlar: profile-final/01_profil_tr.png, profile-final/14_ayarlar_koyu_tr.png, support/34-01_ana_tr.png, support-dark/35-05_detay_tr_koyu.png.

Gerçek cihaz/platform izin akışları bu alt görevde çalıştırılmadı. Backend, ortak tema, l10n ve bildirim tercih davranışları bu değişikliğin kapsamı dışındadır.