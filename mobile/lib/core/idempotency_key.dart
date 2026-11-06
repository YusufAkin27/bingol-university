import 'api.dart' show ApiError;

/// Çift gönderimi engelleyen anahtar (`Idempotency-Key`): bir "gönderme niyeti" için BİR kez üretilir, yeniden
/// denemelerde aynen kullanılır; sunucu aynı anahtarla gelen ikinci isteği yeni kayıt açmadan aynı sonuçla yanıtlar.
String newIdempotencyKey([String prefix = 'k']) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = (Object().hashCode ^ t.hashCode).toRadixString(36);
  return '$prefix$t-$r';
}

/// Başarısız bir gönderimden sonra anahtar korunmalı mı: yanıt alınamadıysa (ağ/zaman aşımı/5xx) sunucuda kayıt
/// oluşmuş olabilir, aynı anahtarla yeniden denenir; sunucu açıkça reddettiyse (4xx) niyet bitmiştir, yeni anahtar alınır.
bool keepKeyAfterError(Object e) {
  if (e is ApiError) return e.status == 0 || e.status >= 500 || e.status == 408;
  return true;
}
