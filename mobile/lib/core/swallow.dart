import 'error_log.dart';

/// Bilerek yutulan ama kullanıcı verisini/eşitlemeyi etkileyebilecek hataları sessiz bırakmaz:
/// yalnız hata TÜRÜ yerel hata günlüğüne yazılır (mesaj, yığın, kimlik, jeton ASLA).
/// Hiç fırlatmaz. [label] kısa ASCII kaynak adıdır (ör. `widget_store.put`).
void swallow(String label, Object error, {ErrorLog? log}) {
  try {
    final safe = label.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '');
    final l = safe.length > 40 ? safe.substring(0, 40) : safe;
    (log ?? ErrorLog.instance).report(error, source: 'swallow:$l');
  } catch (_) {
    // Günlükleme kendisi hata verirse yapılacak bir şey yok.
  }
}
