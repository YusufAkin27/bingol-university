import 'api.dart';

/// Bir açık oturum (`GET /auth/sessions` satırı). Ham IP gelmez: [ipMasked] sunucuda kısmen maskelenir.
/// Sözleşme: docs/changes/auth.md "Çoklu oturum + Cihazlarım".
class UserSessionInfo {
  const UserSessionInfo({
    required this.id,
    this.client = 'mobile',
    this.platform = '',
    this.deviceName = '',
    this.appVersion = '',
    this.ipMasked = '',
    this.createdAt,
    this.lastUsedAt,
    this.current = false,
  });

  /// Kimliği olmayan ya da bozuk satır null döner (listeye alınmaz).
  static UserSessionInfo? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    String s(String k) => j[k] is String ? (j[k] as String).trim() : '';
    return UserSessionInfo(
      id: id,
      client: s('client').isEmpty ? 'mobile' : s('client'),
      platform: s('platform').toUpperCase(),
      deviceName: s('deviceName'),
      appVersion: s('appVersion'),
      ipMasked: s('ipMasked'),
      createdAt: DateTime.tryParse(s('createdAt'))?.toLocal(),
      lastUsedAt: DateTime.tryParse(s('lastUsedAt'))?.toLocal(),
      current: j['current'] == true,
    );
  }

  final String id;
  final String client;

  /// ANDROID | IOS | WEB | UNKNOWN (ya da boş).
  final String platform;
  final String deviceName;
  final String appVersion;
  final String ipMasked;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  /// İsteği yapan oturum ("Bu cihaz").
  final bool current;

  bool get isWeb => platform == 'WEB' || client == 'web';
}

/// Cihazlarım uçları (oturum açık kullanıcı).
class UserSessionsApi {
  UserSessionsApi(this.api);

  final ApiClient api;

  /// Açık oturumlar; bu cihaz başta. Önbelleğe takılmamak için `force`.
  Future<List<UserSessionInfo>> list() async {
    final res = await api.get('/auth/sessions', force: true);
    if (res is! List) throw ApiError(0, 'BAD_RESPONSE', '');
    return res.map(UserSessionInfo.tryParse).whereType<UserSessionInfo>().toList();
  }

  /// Belirli cihazdan çıkış (204). Olmayan/kapanmış oturum 404 `SESSION_NOT_FOUND`.
  Future<void> revoke(String id) => api.delete('/auth/sessions/${Uri.encodeComponent(id)}');
}
