import 'package:flutter/foundation.dart';

/// Okunmamış sayaçları. Kabuk (shell) periyodik olarak günceller; ilgili sayfa okunca değeri düşürür.
class AppBadges {
  /// Okunmamış uygulama içi bildirim sayısı (ana sayfa çanı).
  final notifications = ValueNotifier<int>(0);

  /// Kalp (Hareketler) okunmamis sosyal etkilesim sayisi; zilden bagimsiz (sunucuda ayri hesaplanir).
  final social = ValueNotifier<int>(0);

  /// Kalp icin islem bekleyen istek sayisi (takip istegi + yonetebildigim kuluplerin uyelik basvurusu).
  final socialPending = ValueNotifier<int>(0);


  /// Tüm sohbetlerdeki okunmamış mesaj toplamı (alt gezinmede Sohbet rozeti).
  final chat = ValueNotifier<int>(0);

  /// Sohbet listesi sunucuda değişti (kulüpten ayrılma vb.): sohbet sekmesi dinleyip yenilemeli.
  final conversationsDirty = ValueNotifier<int>(0);

  void reset() {
    notifications.value = 0;
    social.value = 0;
    socialPending.value = 0;
    chat.value = 0;
    conversationsDirty.value = 0;
  }
}
