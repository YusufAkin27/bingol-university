import 'package:http/http.dart' as http;

import 'fake_app.dart';

/// İki faktörlü doğrulama uçlarının durumlu sahte uygulaması (docs/TWO_FACTOR_API.md).
class FakeTwoFactor {
  FakeTwoFactor(this.b, {this.enabled = false, this.requireOnLogin = false}) {
    b.handlers.add(handle);
  }

  final FakeBackend b;

  /// Hesapta 2FA açık mı (`GET /auth/2fa`).
  bool enabled;

  /// true: `POST /auth/login` 202 + challenge döner (tanınmayan cihaz).
  bool requireOnLogin;

  String validCode = '123456';
  String challengeToken = 'challenge-abc';
  String password = 'Sifre1234';

  /// Challenge'ın ölmesinden önceki yanlış kod hakkı (sunucuda 5).
  int wrongBudget = 5;
  int _wrong = 0;

  /// Yeniden gönderme hakkı (sunucuda 3 / 10 dk); aşılınca 429.
  int resendBudget = 3;

  /// true: `POST /auth/login/2fa` challenge'ı süresi dolmuş sayar.
  bool challengeExpired = false;

  /// true: giriş 429 TWO_FACTOR_LOCKED döner.
  bool locked = false;

  /// true: `GET /auth/2fa` 500 döner (durum yüklenemedi).
  bool statusFails = false;

  int enableRequests = 0;
  int resends = 0;
  final List<Map<String, dynamic>> devices = [];
  int _id = 10;

  Map<String, dynamic> addDevice(String label, {bool current = false}) {
    final d = {
      'id': ++_id,
      'label': label,
      'createdAt': '2026-10-01T10:00:00Z',
      'lastUsedAt': '2026-11-01T12:30:00Z',
      'current': current,
    };
    devices.add(d);
    return d;
  }

  static Map<String, dynamic> _err(String code, String message) => {'code': code, 'message': message};

  static const _tokens = {
    'accessToken': 'access-1',
    'refreshToken': 'refresh-1',
    'expiresInSeconds': 900,
    'tokenType': 'Bearer',
  };

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    final body = req.body.isEmpty ? null : req.body;
    Map<String, dynamic>? json;
    if (body != null) {
      json = (b.bodies['$m $path'] as Map?)?.cast<String, dynamic>();
    }
    switch ('$m $path') {
      case 'POST /auth/login':
        if (locked) {
          return FakeResult.json(_err('TWO_FACTOR_LOCKED', 'Çok sayıda hatalı doğrulama kodu girildi.'), status: 429);
        }
        if (requireOnLogin) {
          return FakeResult.json({
            'twoFactorRequired': true,
            'challengeToken': challengeToken,
            'emailHint': 'ay***@bingol.edu.tr',
            'expiresInSeconds': 600,
          }, status: 202);
        }
        return const FakeResult.json(_tokens);
      case 'POST /auth/login/2fa':
        if (challengeExpired || json?['challengeToken'] != challengeToken) {
          return FakeResult.json(_err('TWO_FACTOR_CHALLENGE_EXPIRED', 'Doğrulama oturumunun süresi doldu. Lütfen tekrar giriş yapın.'),
              status: 400);
        }
        if (json?['code'] != validCode) {
          _wrong++;
          if (_wrong >= wrongBudget) challengeExpired = true;
          return FakeResult.json(_err('TWO_FACTOR_CODE_INVALID', 'Doğrulama kodu geçersiz veya süresi dolmuş.'), status: 400);
        }
        return const FakeResult.json(_tokens);
      case 'POST /auth/login/2fa/resend':
        if (challengeExpired) {
          return FakeResult.json(_err('TWO_FACTOR_CHALLENGE_EXPIRED', 'Doğrulama oturumunun süresi doldu. Lütfen tekrar giriş yapın.'),
              status: 400);
        }
        resends++;
        if (resends > resendBudget) {
          return FakeResult.json(_err('RATE_LIMITED', 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.'), status: 429);
        }
        return const FakeResult.json({'expiresInSeconds': 600}, status: 202);
      case 'GET /auth/2fa':
        if (statusFails) return FakeResult.json(_err('SERVER_ERROR', 'Sunucu hatası.'), status: 500);
        return FakeResult.json({
          'enabled': enabled,
          'trustedDeviceCount': devices.length,
          'currentDeviceTrusted': devices.any((d) => d['current'] == true),
        });
      case 'POST /auth/2fa/enable/request':
        if (enabled) return FakeResult.json(_err('TWO_FACTOR_ALREADY_ENABLED', 'İki faktörlü doğrulama zaten açık.'), status: 409);
        enableRequests++;
        return const FakeResult.json({'message': 'Doğrulama kodu e-posta adresinize gönderildi.'}, status: 202);
      case 'POST /auth/2fa/enable/confirm':
        if (json?['code'] != validCode) {
          return FakeResult.json(_err('TWO_FACTOR_CODE_INVALID', 'Doğrulama kodu geçersiz veya süresi dolmuş.'), status: 400);
        }
        enabled = true;
        if (!devices.any((d) => d['current'] == true)) addDevice('android 2.0.6', current: true);
        return const FakeResult.json({'enabled': true});
      case 'POST /auth/2fa/disable':
        if (json?['password'] != password) {
          return FakeResult.json(_err('INVALID_PASSWORD', 'Şifre hatalı.'), status: 400);
        }
        enabled = false;
        devices.clear();
        return const FakeResult.json({'enabled': false});
      case 'GET /auth/2fa/devices':
        return FakeResult.json(devices);
    }
    final del = RegExp(r'^/auth/2fa/devices/(\d+)$').firstMatch(path);
    if (m == 'DELETE' && del != null) {
      final id = int.parse(del.group(1)!);
      final before = devices.length;
      devices.removeWhere((d) => d['id'] == id);
      if (devices.length == before) return FakeResult.json(_err('NOT_FOUND', 'Bulunamadı.'), status: 404);
      return const FakeResult.json(null, status: 204);
    }
    return null;
  }
}
