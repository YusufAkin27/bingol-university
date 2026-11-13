# Animasyon denetimi: posts-group (posts, reels, discover, saved, search, follow)

Genel: kapsam zaten olgun. Ortak yardimcilar (BuMotion.of/reduced, BuPressable, BuStaggerScope/Item, BuHero) yaygin kullaniliyor.

| Sayfa | Dosya:satir | Mevcut | Eksik / zayif | Oneri / durum |
|---|---|---|---|---|
| Gonderi karti / medya | posts/post_card.dart:89-169 | gorsel fade-in, BuHero | yok | - |
| Begeni | posts/like_button.dart:84-531 | olcek dizisi 520 ms, sayac, cift dokunma kalbi; reduced saygisi var | sure 520 ms > 300 ms (ikon vurgusu, bilincli) | birakildi (tek ikon, ucuz transform) |
| Yorumlar | posts/comments/comment_tile.dart:118-230, comment_sheet.dart:340 | AnimatedContainer/Scale/Size | yok | - |
| Compose | posts/compose_post_page.dart | Switcher/Size/Opacity | yok | - |
| Foto goruntuleyici | posts/post_photo_viewer.dart | fade rota, zoom/geri animasyonu | yok | - |
| Video | posts/post_video.dart:226 | flash 700 ms (oynat/durdur ipucu) | - | video akisina dokunulmadi |
| Reels | reels/reels_feed.dart | PageView, GestureDetector | dokunma geri bildirimi yok | video oynatmayi etkilememek icin DEGISTIRILMEDI |
| Kesfet | discover/discover_masonry.dart:334-482 | ilk 6 kutu stagger, gorsel fade | yok | - |
| Oneri kartlari | discover/discover_suggestions.dart:74,165 | yok (InkWell/GestureDetector) | basinca olcek yok | oneri: BuPressable (dosya baska ajanla cakismasin diye dokunulmadi) |
| Kaydedilenler | saved/saved_items_page.dart:270 | yok | liste girisi yok | YAPILDI: BuStaggerScope + BuStaggerItem (ilk 8 satir) |
| Raporlarim | saved/my_reports_page.dart:136 | yok | liste girisi yok | YAPILDI: BuStaggerItem |
| Sessize alinanlar | saved/muted_items_page.dart:95 | yok | liste girisi yok | oneri: ListView(children) oldugundan stagger atlandi (kucuk liste) |
| Arama | search/search_page.dart:788,1059,1209,1325 | stagger, BuPressable, AnimatedContainer/TextStyle | yok | - |
| Takip listesi/oneriler | follow/follow_list_page.dart:213, follow_suggestions.dart:104 | stagger | yok | - |
| Takip istekleri | follow/follow_requests_page.dart:122,319 | AnimatedAlign, satir kapanma gecikmesi | liste girisi yok | tek children ListView, dokunulmadi |
| Takip dugmesi | follow/follow_button.dart:223-360 | BuPressable + AnimatedContainer/Switcher | yok | - |
