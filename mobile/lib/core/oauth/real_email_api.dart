import '../api.dart';
import '../secure_store.dart';

/// Apple "E-postamı gizle" röle alan adı (sunucudaki `RelayEmails` ile aynı). İstemci yalnız kullanıcıya erken, anlaşılır geri bildirim
/// verir; asıl karar sunucudadır (`400 EMAIL_RELAY_NOT_ALLOWED`).
bool isRelayEmail(String? email) {
  final s = (email ?? '').trim().toLowerCase();
  final at = s.lastIndexOf('@');
  return at > 0 && s.substring(at + 1) == 'privaterelay.appleid.com';
}

/// `GET /users/me` ve OAuth giriş yanıtındaki gerçek e-posta durumu.
/// - [needsReal]: hesap e-postası Apple gizli adresi (arayüz "Gerçek e-posta adresiniz" adımını gösterir).
/// - [required]: yeni röle hesapta ZORUNLU kapı (sunucu yazmayı `403 REAL_EMAIL_REQUIRED` ile keser); mevcut hesapta false =
///   atlanabilir yumuşak adım.
class RealEmailStatus {
  const RealEmailStatus({this.needsReal = false, this.required = false});

  final bool needsReal;
  final bool required;

  static const none = RealEmailStatus();

  /// Alanlar yoksa (eski sunucu) durum "gerekmez"dir; `required` yalnız `needsReal` iken anlamlıdır.
  factory RealEmailStatus.fromJson(Object? json) {
    if (json is! Map) return none;
    final needs = json['emailNeedsReal'] == true;
    return RealEmailStatus(needsReal: needs, required: needs && json['realEmailRequired'] == true);
  }
}

/// `POST /users/me/email/start` yanıtı.
class RealEmailStart {
  const RealEmailStart({required this.emailMasked, this.expiresInSeconds = 600, this.resendInSeconds = 180});

  final String emailMasked;
  final int expiresInSeconds;
  final int resendInSeconds;
}

/// Gerçek e-posta uçları (kimlikli; kapıda da çalışır). Sözleşme: docs/changes/auth.md "Gercek e-posta (role) dogrulamasi".
class RealEmailApi {
  RealEmailApi(this.api);

  final ApiClient api;

  /// Adrese 6 haneli kod gönderir (kod YENİ adrese gider, röle adresine asla). Hatalar [ApiError]:
  /// 400 `EMAIL_RELAY_NOT_ALLOWED` / `EMAIL_ALIAS_NOT_ALLOWED` / `EMAIL_UNCHANGED` / `VALIDATION_ERROR`,
  /// 403 `EMAIL_CHANGE_NOT_ALLOWED`, 429 `RESEND_COOLDOWN` (+Retry-After), 503 `MAIL_QUOTA_EXHAUSTED`.
  Future<RealEmailStart> start(String email) async {
    final r = await api.post('/users/me/email/start', {'email': email});
    if (r is! Map) throw ApiError(0, 'BAD_RESPONSE', '');
    final masked = r['emailMasked'];
    final exp = r['expiresInSeconds'];
    final resend = r['resendInSeconds'];
    return RealEmailStart(
      emailMasked: masked is String ? masked : email,
      expiresInSeconds: exp is num && exp > 0 ? exp.toInt() : 600,
      resendInSeconds: resend is num && resend > 0 ? resend.toInt() : 180,
    );
  }

  /// Kodu doğrular; başarıda hesabın yeni (tek) e-postasını döner. Hatalar: 400 `INVALID_CODE`, 429 `TOO_MANY_ATTEMPTS`,
  /// 409 `EMAIL_UNAVAILABLE` (adres başka hesapta kayıtlı).
  Future<String> verify(String code) async {
    final r = await api.post('/users/me/email/verify', {'code': code});
    final e = r is Map ? r['email'] : null;
    if (e is! String || e.isEmpty) throw ApiError(0, 'BAD_RESPONSE', '');
    return e;
  }
}

/// Yumuşak adım ("Şimdi değil") hatırlatma ertelemesi: kullanıcı atlarsa aynı cihazda bu kadar süre tekrar sorulmaz.
/// Zorunlu kapıda (yeni hesap) erteleme YOKTUR.
class RealEmailSoftSkip {
  RealEmailSoftSkip._();

  static const Duration snooze = Duration(days: 3);
  static const _key = 'real_email_soft_skip';

  static String _value(int? userId, DateTime now) => '${userId ?? 0}:${now.add(snooze).millisecondsSinceEpoch}';

  /// [userId] için erteleme sürüyor mu? Depo okunamazsa false (adım gösterilir).
  static Future<bool> isSnoozed(int? userId, {DateTime? now}) async {
    try {
      final v = await kDeviceSecureStorage.read(key: _key);
      if (v == null) return false;
      final i = v.indexOf(':');
      if (i < 0 || v.substring(0, i) != '${userId ?? 0}') return false;
      final until = int.tryParse(v.substring(i + 1));
      return until != null && until > (now ?? DateTime.now()).millisecondsSinceEpoch;
    } catch (_) {
      return false;
    }
  }

  static Future<void> snoozeNow(int? userId, {DateTime? now}) async {
    try {
      await kDeviceSecureStorage.write(key: _key, value: _value(userId, now ?? DateTime.now()));
    } catch (_) {
      // Depo yazılamazsa bu oturumda adım yalnızca bellekte ertelenir (kapı kendi durumunu tutar).
    }
  }
}
