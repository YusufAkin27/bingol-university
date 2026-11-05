import 'api.dart';

/// Giriş ikinci adımı (202): şifre doğru, sunucu e-postaya 6 haneli kod gönderdi. Belirteç YALNIZ bellekte tutulur;
/// diske, günlüğe ya da analitiğe yazılmaz ([toString] bilerek gizler).
class TwoFactorChallenge {
  TwoFactorChallenge({required this.token, this.emailHint = '', this.expiresInSeconds = 600});

  /// Sunucu yanıtından ayrıştırır; `twoFactorRequired:true` ve boş olmayan `challengeToken` yoksa null.
  static TwoFactorChallenge? tryParse(Object? json) {
    if (json is! Map || json['twoFactorRequired'] != true) return null;
    final token = json['challengeToken'];
    if (token is! String || token.isEmpty) return null;
    final hint = json['emailHint'];
    final ttl = json['expiresInSeconds'];
    return TwoFactorChallenge(
      token: token,
      emailHint: hint is String ? hint : '',
      expiresInSeconds: ttl is num && ttl > 0 ? ttl.toInt() : 600,
    );
  }

  final String token;

  /// Maskeli e-posta ("ay***@bingol.edu.tr"); boş olabilir.
  final String emailHint;
  final int expiresInSeconds;

  @override
  String toString() => 'TwoFactorChallenge(<gizli>)';
}

/// `GET /auth/2fa`.
class TwoFactorStatus {
  const TwoFactorStatus({required this.enabled, this.trustedDeviceCount = 0, this.currentDeviceTrusted = false});

  factory TwoFactorStatus.fromJson(Object? j) {
    if (j is! Map || j['enabled'] is! bool) throw ApiError(0, 'BAD_RESPONSE', '');
    final c = j['trustedDeviceCount'];
    return TwoFactorStatus(
      enabled: j['enabled'] as bool,
      trustedDeviceCount: c is num ? c.toInt() : 0,
      currentDeviceTrusted: j['currentDeviceTrusted'] == true,
    );
  }

  final bool enabled;
  final int trustedDeviceCount;
  final bool currentDeviceTrusted;
}

/// `GET /auth/2fa/devices` satırı. Ham cihaz kimliği sunucudan gelmez; yalnız etiket ve zamanlar.
class TwoFactorDevice {
  const TwoFactorDevice({required this.id, required this.label, this.createdAt, this.lastUsedAt, this.current = false});

  static TwoFactorDevice? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! num) return null;
    final label = j['label'];
    return TwoFactorDevice(
      id: id.toInt(),
      label: label is String ? label : '',
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toLocal(),
      lastUsedAt: DateTime.tryParse('${j['lastUsedAt'] ?? ''}')?.toLocal(),
      current: j['current'] == true,
    );
  }

  final int id;
  final String label;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final bool current;
}

/// Ayar uçları (oturum açık kullanıcı). Sözleşme: docs/TWO_FACTOR_API.md. `closeOtherSessions` gönderilmez.
class TwoFactorApi {
  TwoFactorApi(this.api);

  final ApiClient api;

  Future<TwoFactorStatus> status() async => TwoFactorStatus.fromJson(await api.get('/auth/2fa', force: true));

  Future<List<TwoFactorDevice>> devices() async {
    final res = await api.get('/auth/2fa/devices', force: true);
    if (res is! List) throw ApiError(0, 'BAD_RESPONSE', '');
    return res.map(TwoFactorDevice.tryParse).whereType<TwoFactorDevice>().toList();
  }

  /// Açma kodunu e-postaya gönderir (202). Zaten açıksa 409 TWO_FACTOR_ALREADY_ENABLED.
  Future<void> requestEnable() => api.post('/auth/2fa/enable/request');

  Future<void> confirmEnable(String code) => api.post('/auth/2fa/enable/confirm', {'code': code.trim()});

  /// Şifre ister; yanlışsa 400 INVALID_PASSWORD. Tüm güvenilen cihazlar silinir.
  Future<void> disable(String password) => api.post('/auth/2fa/disable', {'password': password});

  Future<void> removeDevice(int id) => api.delete('/auth/2fa/devices/$id');
}
