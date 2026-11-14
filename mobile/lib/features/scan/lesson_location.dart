/// Ders yoklaması için konum: tarayıcı yalnız bu küçük arayüzü bilir (testte sahtesi konur, eklenti gerekmez).
library;

/// Konum alınamama nedeni.
enum LessonLocationFailure {
  /// Kullanıcı izni reddetti (tekrar sorulabilir).
  denied,

  /// İzin kalıcı reddedildi: yalnız sistem ayarlarından açılır.
  deniedForever,

  /// Cihazın konum servisi kapalı.
  serviceOff,

  /// Süre içinde konum alınamadı.
  timeout,

  /// Bu cihazda/yapıda konum yok.
  unavailable,
}

/// Alınan konum: metre cinsinden doğruluk dahil. Ham koordinatlar yalnız yoklama isteğiyle sunucuya gider; saklanmaz/günlüğe yazılmaz.
class LessonPosition {
  const LessonPosition(this.latitude, this.longitude, this.accuracyM);

  final double latitude;
  final double longitude;
  final double accuracyM;
}

/// [position] ya da [failure] dolu olur (ikisi birden değil).
class LessonLocationResult {
  const LessonLocationResult.ok(LessonPosition this.position) : failure = null;
  const LessonLocationResult.failed(LessonLocationFailure this.failure) : position = null;

  final LessonPosition? position;
  final LessonLocationFailure? failure;
}

abstract class LessonLocationProvider {
  /// Anlık konumu verir; hiçbir koşulda istisna fırlatmaz (hatalar [LessonLocationFailure] olarak döner).
  Future<LessonLocationResult> current();
}

/// Konum eklentisi bağlı değilken varsayılan: konum yok, kod koordinatsız gönderilir (sunucu karar verir).
class UnavailableLessonLocationProvider implements LessonLocationProvider {
  const UnavailableLessonLocationProvider();

  @override
  Future<LessonLocationResult> current() async => const LessonLocationResult.failed(LessonLocationFailure.unavailable);
}
