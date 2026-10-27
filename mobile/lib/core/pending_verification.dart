import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identifier.dart';

/// Doğrulaması bekleyen kayıt (şifre ASLA saklanmaz).
class PendingVerification {
  const PendingVerification(this.identifier, this.at);

  final String identifier;
  final DateTime at;

  String get email => fullEmail(identifier);
}

/// Bekleyen e-posta doğrulamasını güvenli yerel depoda tutar; 72 saat sonra silinir.
class PendingVerificationStore {
  PendingVerificationStore({DateTime Function()? now}) : _now = now ?? DateTime.now, _mem = null;

  /// Testler için bellek içi depo.
  PendingVerificationStore.memory({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _mem = {};

  static const key = 'pending_verification';
  static const ttl = Duration(hours: 72);

  final DateTime Function() _now;
  final Map<String, String>? _mem;
  final _storage = const FlutterSecureStorage();

  Future<String?> _read() async {
    final m = _mem;
    return m != null ? m[key] : await _storage.read(key: key);
  }

  Future<void> _write(String v) async {
    if (_mem != null) {
      _mem[key] = v;
    } else {
      await _storage.write(key: key, value: v);
    }
  }

  Future<void> save(String identifier) async {
    try {
      await _write(jsonEncode({'id': normalizeIdentifier(identifier), 'at': _now().millisecondsSinceEpoch}));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      if (_mem != null) {
        _mem.remove(key);
      } else {
        await _storage.delete(key: key);
      }
    } catch (_) {}
  }

  /// Süresi dolmuşsa siler ve null döner.
  Future<PendingVerification?> load() async {
    try {
      final raw = await _read();
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final id = m['id'] as String?;
      final at = DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt());
      if (id == null || id.isEmpty || _now().difference(at) >= ttl) {
        await clear();
        return null;
      }
      return PendingVerification(id, at);
    } catch (_) {
      return null;
    }
  }
}
