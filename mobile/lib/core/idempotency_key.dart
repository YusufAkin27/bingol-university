import 'dart:math' show Random;

import 'api.dart' show ApiError;

final Random _keyRandom = Random.secure();

/// Çift gönderimi engelleyen anahtar (`Idempotency-Key`): bir "gönderme niyeti" için BİR kez üretilir, yeniden
/// denemelerde aynen kullanılır; sunucu aynı anahtarla gelen ikinci isteği yeni kayıt açmadan aynı sonuçla yanıtlar.
String newIdempotencyKey([String prefix = 'k']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  // Güvenli rastgele 2x32 bit: aynı mikrosaniyede iki niyet/cihaz çakışırsa sunucu ikinci kaydı yutmasın.
  final r = _keyRandom.nextInt(1 << 32).toRadixString(36) + _keyRandom.nextInt(1 << 32).toRadixString(36);
  return '$prefix$t-$r';
}

/// Başarısız bir gönderimden sonra anahtar korunmalı mı: yanıt alınamadıysa (ağ/zaman aşımı/5xx) sunucuda kayıt
/// oluşmuş olabilir, aynı anahtarla yeniden denenir; sunucu açıkça reddettiyse (4xx) niyet bitmiştir, yeni anahtar alınır.
bool keepKeyAfterError(Object e) {
  if (e is ApiError) return e.status == 0 || e.status >= 500 || e.status == 408;
  return true;
}
