import 'package:flutter/foundation.dart';

/// Okunmamış sayaçları. Kabuk (shell) periyodik olarak günceller; ilgili sayfa okunca değeri düşürür.
class AppBadges {
  /// Okunmamış uygulama içi bildirim sayısı (ana sayfa çanı).
  final notifications = ValueNotifier<int>(0);

  /// Tüm sohbetlerdeki okunmamış mesaj toplamı (alt gezinmede Sohbet rozeti).
  final chat = ValueNotifier<int>(0);

  /// Sohbet listesi sunucuda değişti (kulüpten ayrılma vb.): sohbet sekmesi dinleyip yenilemeli.
  final conversationsDirty = ValueNotifier<int>(0);

  void reset() {
    notifications.value = 0;
    chat.value = 0;
    conversationsDirty.value = 0;
  }
}
