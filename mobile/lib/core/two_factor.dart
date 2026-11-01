import 'api.dart';

/// İki faktörlü doğrulama (e-posta kodu) istemci katmanı. Sözleşme: docs/TWO_FACTOR_API.md.
///
/// Girişte tanınmayan cihaz: `POST /auth/login` 202 [TwoFactorChallenge] döner (token yok). Kod ekranı
/// `POST /auth/login/2fa` ile oturumu açar. Güvenilen cihazdan giriş 200 döner; istemcide özel mantık yok.

/// `POST /auth/login` 202 yanıtı: kod e-postaya gitti, oturum henüz açılmadı.
class TwoFactorChallenge {
  const TwoFactorChallenge({required this.token, required this.emailHint, required this.expiresInSeconds});

  /// Opak, 10 dk geçerli, tek kullanımlık anahtar.
  final String token;

  /// Maskeli adres ("ay***@bingol.edu.tr").
  final String emailHint;
  final int expiresInSeconds;

  /// Giriş yanıtı 2FA gerektiriyorsa çözer; aksi halde (normal TokenResponse) null.
  static TwoFactorChallenge? tryParse(Object? res) {
    if (res is! Map || res['twoFactorRequired'] != true) return null;
    final token = res['challengeToken'];
    if (token is! String || token.isEmpty) throw ApiError(0, 'BAD_RESPONSE', '');
    final hint = res['emailHint'];
    final exp = res['expiresInSeconds'];
    return TwoFactorChallenge(
      token: token,
      emailHint: hint is String ? hint : '',
      expiresInSeconds: exp is num ? exp.toInt() : 600,
    );
  }
}

/// `GET /auth/2fa`.
class TwoFactorStatus {
  const TwoFactorStatus({required this.enabled, required this.trustedDeviceCount, required this.currentDeviceTrusted});

  final bool enabled;
  final int trustedDeviceCount;
  final bool currentDeviceTrusted;

  factory TwoFactorStatus.fromJson(Object? j) {
    if (j is! Map) throw ApiError(0, 'BAD_RESPONSE', '');
    final c = j['trustedDeviceCount'];
    return TwoFactorStatus(
      enabled: j['enabled'] == true,
      trustedDeviceCount: c is num ? c.toInt() : 0,
      currentDeviceTrusted: j['currentDeviceTrusted'] == true,
    );
  }

  TwoFactorStatus copyWith({bool? enabled, int? trustedDeviceCount}) => TwoFactorStatus(
        enabled: enabled ?? this.enabled,
        trustedDeviceCount: trustedDeviceCount ?? this.trustedDeviceCount,
        currentDeviceTrusted: currentDeviceTrusted,
      );
}

/// `GET /auth/2fa/devices` satırı.
class TrustedDevice {
  const TrustedDevice({required this.id, required this.label, this.createdAt, this.lastUsedAt, required this.current});

  final int id;
  final String label;
  final String? createdAt;
  final String? lastUsedAt;
  final bool current;

  static TrustedDevice? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! num) return null;
    final label = j['label'];
    final c = j['createdAt'];
    final u = j['lastUsedAt'];
    return TrustedDevice(
      id: id.toInt(),
      label: label is String ? label : '',
      createdAt: c is String ? c : null,
      lastUsedAt: u is String ? u : null,
      current: j['current'] == true,
    );
  }
}

/// Ayarlar tarafı uçları (JWT gerekir). Güvenlik durumu bayat gösterilmesin diye GET'ler `force` ile gider.
class TwoFactorService {
  TwoFactorService(this.api);

  final ApiClient api;

  Future<TwoFactorStatus> status() async => TwoFactorStatus.fromJson(await api.get('/auth/2fa', force: true));

  /// Açma kodunu e-postaya gönderir (202). Zaten açıksa 409 TWO_FACTOR_ALREADY_ENABLED.
  Future<void> requestEnable() => api.post('/auth/2fa/enable/request');

  Future<void> confirmEnable(String code) => api.post('/auth/2fa/enable/confirm', {'code': code.trim()});

  /// Yanlış şifre 400 INVALID_PASSWORD.
  Future<void> disable(String password) => api.post('/auth/2fa/disable', {'password': password});

  Future<List<TrustedDevice>> devices() async {
    final res = await api.get('/auth/2fa/devices', force: true);
    if (res is! List) throw ApiError(0, 'BAD_RESPONSE', '');
    return res.map(TrustedDevice.tryParse).whereType<TrustedDevice>().toList();
  }

  Future<void> removeDevice(int id) => api.delete('/auth/2fa/devices/$id');
}
