import 'package:flutter/foundation.dart';

/// Bir kullanıcı engellenince açık akışların (Keşfet, Reels, gönderi sayfası) o yazarın TÜM gönderilerini hemen
/// düşürmesi için küçük olay veri yolu. Yalnızca o anda ekranda olan listelere haber verir; sunucu zaten engelli
/// yazarın içeriğini sonraki isteklerde göndermez.
class BlockBus extends ChangeNotifier {
  BlockBus._();

  static final BlockBus instance = BlockBus._();

  int _last = 0;

  /// En son engellenen kullanıcı kimliği.
  int get lastBlocked => _last;

  /// [userId] engellendi: dinleyenler listelerinden bu yazarın gönderilerini çıkarır.
  void blocked(int userId) {
    _last = userId;
    notifyListeners();
  }
}
