# Animasyon denetimi: forum-group (features/forum, polls, support)

Genel durum: kapsam zaten olgun. Tüm süreler BuMotion.of ile azaltılmış harekete saygılı; yalnız transform/opacity/boyut kullanılıyor.

| Sayfa/parça | Dosya | Mevcut | Eksik / zayıf | Aksiyon |
|---|---|---|---|---|
| Forum ana akış | forum_home_page.dart:395,453 | yeni konu girişi (_Entrance), BuPressable, kaydırma-başa | ilk yükte kart girişi yok (SliverList; kapsam sarılamaz) | Öneri: akışı BuStaggerScope taşıyan bir sliver sarmalayıcıya alın (ortak widget gerekir) |
| Sayfalı liste (kaydedilenler, etkinlik, arama) | widgets/forum_paged_list.dart:203 | yok | liste girişi animasyonsuz | YAPILDI: BuStaggerScope + BuStaggerItem (ilk 6, bir kez) |
| Beğeni (konu/yorum) | forum_like_button.dart:49, comment_like_button.dart:30 | pop (TweenSequence), renk geçişi | yok | - |
| Anket çubukları | poll_view.dart:315, polls/poll_parts.dart:127, poll_detail_page.dart:497 | genişlik TweenAnimationBuilder, BuCountUp | yok | - |
| Yorum bölümü | comment_section.dart:75, comment_card.dart:82 | giriş/çıkış, vurgu AnimatedContainer | yok | - |
| Oluştur/düzenle | create_topic_page.dart, edit_topic_page.dart | AnimatedSize/Opacity/Switcher | yok | - |
| Anket listesi/detay/form | poll_list_page.dart:153, poll_detail_page.dart:274, poll_form_page.dart | BuStaggerItem, AnimatedSwitcher/Size | yok | - |
| Destek (ana, talep, öneri, geri bildirim) | support_*.dart | BuStaggerItem, AnimatedSize/Rotation, AnimatedSwitcher | SSS satırları (support_page.dart:204) girişsiz | Öneri: ilk 6 SSS satırına BuStaggerItem; düşük öncelik |

Ortak dosya önerisi: BuStaggerScope'un sliver sürümü (SliverList için) eklenirse forum ana akışı ve SSS listesi kazanır.
