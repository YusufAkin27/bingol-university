import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api.dart' show Tokens;
import '../secure_store.dart';

/// Cihazdaki çoklu hesap kaydı (Instagram benzeri). Her hesabın belirteçleri güvenli depoda (Keychain/Keystore)
/// AYRI anahtarda durur; dizin yalnız gösterim bilgisi taşır (kullanıcı kimliği, ad, kullanıcı adı, avatar, MASKELİ
/// e-posta). Ham e-posta ve parola saklanmaz; belirteçler hiçbir `toString`/log çıktısında yer almaz.
class StoredAccount {
  const StoredAccount({
    required this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.emailMasked,
    this.expired = false,
    this.addedAt,
  });

  final int userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? emailMasked;

  /// Sunucu bu hesabın oturumunu iptal etti (401): belirteçler silindi, yeniden giriş gerekir.
  final bool expired;
  final int? addedAt;

  StoredAccount copyWith({String? displayName, String? username, String? avatarUrl, String? emailMasked, bool? expired}) =>
      StoredAccount(
        userId: userId,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        emailMasked: emailMasked ?? this.emailMasked,
        expired: expired ?? this.expired,
        addedAt: addedAt,
      );

  Map<String, Object?> toJson() => {
        'id': userId,
        if (displayName != null) 'name': displayName,
        if (username != null) 'un': username,
        if (avatarUrl != null) 'av': avatarUrl,
        if (emailMasked != null) 'mail': emailMasked,
        if (expired) 'exp': true,
        if (addedAt != null) 'added': addedAt,
      };

  static StoredAccount? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! num) return null;
    String? s(Object? v) => v is String && v.isNotEmpty ? v : null;
    return StoredAccount(
      userId: id.toInt(),
      displayName: s(j['name']),
      username: s(j['un']),
      avatarUrl: s(j['av']),
      emailMasked: s(j['mail']),
      expired: j['exp'] == true,
      addedAt: j['added'] is num ? (j['added'] as num).toInt() : null,
    );
  }

  /// Belirteç içermez; log'a düşse bile güvenlidir.
  @override
  String toString() => 'StoredAccount($userId)';
}

/// Anahtar-değer arka ucu (üretimde güvenli depo; testlerde bellek).
abstract class AccountKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureAccountKv implements AccountKv {
  const SecureAccountKv();

  @override
  Future<String?> read(String key) => kDeviceSecureStorage.read(key: key);

  @override
  Future<void> write(String key, String value) => kDeviceSecureStorage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => kDeviceSecureStorage.delete(key: key);
}

class MemoryAccountKv implements AccountKv {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Hesap eklenemedi: cihazda zaten [AccountStore.maxAccounts] hesap var.
class AccountLimitException implements Exception {
  const AccountLimitException();
  @override
  String toString() => 'AccountLimitException';
}

class AccountStore extends ChangeNotifier {
  AccountStore({AccountKv? kv}) : _kv = kv ?? const SecureAccountKv();

  /// Cihaz başına en çok hesap.
  static const maxAccounts = 5;

  /// Güvenli depo anahtarları (iOS yeniden kurulum temizliği `FreshInstallGuard.sessionKeys` bunları da siler).
  static const indexKey = 'acct_index';
  static const tokensKey = 'acct_tokens';

  final AccountKv _kv;
  final List<StoredAccount> _accounts = [];
  final Map<int, Tokens> _tokens = {};
  int? _active;
  bool _loaded = false;
  Future<void> _chain = Future.value();

  List<StoredAccount> get accounts => List.unmodifiable(_accounts);
  int? get activeId => _active;
  bool get isFull => _accounts.length >= maxAccounts;
  bool has(int id) => _accounts.any((a) => a.userId == id);
  StoredAccount? byId(int id) {
    for (final a in _accounts) {
      if (a.userId == id) return a;
    }
    return null;
  }

  StoredAccount? get active => _active == null ? null : byId(_active!);

  /// Belirteci olan (süresi dolmamış) hesap sayısı, [except] hariç.
  int switchableCount({int? except}) => _accounts.where((a) => a.userId != except && !a.expired && _tokens.containsKey(a.userId)).length;

  /// Geçilebilecek ilk hesap: önce [prefer], yoksa listedeki ilk süresi dolmamış.
  StoredAccount? nextSwitchable({int? except, int? prefer}) {
    bool ok(StoredAccount a) => a.userId != except && !a.expired && _tokens.containsKey(a.userId);
    if (prefer != null) {
      final p = byId(prefer);
      if (p != null && ok(p)) return p;
    }
    for (final a in _accounts) {
      if (ok(a)) return a;
    }
    return null;
  }

  Tokens? tokensOf(int id) => _tokens[id];

  /// Diskten yükler (idempotent). Okuma hatasında boş kalır.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _kv.read(indexKey);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map) {
          final list = j['accounts'];
          if (list is List) {
            for (final e in list) {
              final a = StoredAccount.tryParse(e);
              if (a != null && !has(a.userId) && _accounts.length < maxAccounts) _accounts.add(a);
            }
          }
          final act = j['active'];
          _active = act is num ? act.toInt() : null;
        }
      }
      Map<dynamic, dynamic> stored = const {};
      try {
        final tj = await _kv.read(tokensKey);
        final d = tj == null ? null : jsonDecode(tj);
        if (d is Map) stored = d;
      } catch (_) {
        // bozuk kayıt: hesaplar yeniden giriş ister
      }
      for (final a in _accounts.toList()) {
        if (a.expired) continue;
        final t = _parseTokens(stored['${a.userId}']);
        if (t != null) {
          _tokens[a.userId] = t;
        } else {
          _replace(a.copyWith(expired: true)); // belirteç okunamadı: yeniden giriş
        }
      }
      if (_active != null && !has(_active!)) _active = null;
    } catch (_) {
      // Depo okunamazsa liste boş kalır; oturum yalnız tek hesapla çalışır.
    }
    notifyListeners();
  }

  static Tokens? _parseTokens(Object? j) {
    if (j is Map && j['a'] is String && j['r'] is String) return Tokens(j['a'] as String, j['r'] as String);
    return null;
  }

  void _replace(StoredAccount a) {
    final i = _accounts.indexWhere((x) => x.userId == a.userId);
    if (i >= 0) _accounts[i] = a;
  }

  Future<void> _persistIndex() => _serial(() async {
        try {
          await _kv.write(indexKey, jsonEncode({'active': _active, 'accounts': [for (final a in _accounts) a.toJson()]}));
        } catch (_) {
          // Depo yazılamazsa bellekte kalır.
        }
      });

  /// Tüm hesapların belirteçleri tek güvenli anahtarda (hesap kimliği -> çift) durur.
  Future<void> _persistTokens(int id) => _serial(() async {
        try {
          if (_tokens.isEmpty) {
            await _kv.delete(tokensKey);
          } else {
            await _kv.write(tokensKey, jsonEncode({for (final e in _tokens.entries) '${e.key}': {'a': e.value.access, 'r': e.value.refresh}}));
          }
        } catch (_) {
          // Depo yazılamazsa bellekte kalır.
        }
      });

  Future<void> _serial(Future<void> Function() f) {
    final next = _chain.then((_) => f());
    _chain = next.catchError((Object _) {});
    return next;
  }

  /// Hesabı ekler ya da günceller ve belirteçlerini yazar; süresi dolmuş işareti kalkar. Yeni hesap ve liste doluysa
  /// [AccountLimitException].
  Future<void> upsert(
    int id,
    Tokens tokens, {
    String? displayName,
    String? username,
    String? avatarUrl,
    String? email,
  }) async {
    final existing = byId(id);
    if (existing == null && isFull) throw const AccountLimitException();
    final masked = email == null ? null : maskEmail(email);
    if (existing == null) {
      _accounts.add(StoredAccount(
        userId: id,
        displayName: displayName,
        username: username,
        avatarUrl: avatarUrl,
        emailMasked: masked,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      _replace(existing.copyWith(displayName: displayName, username: username, avatarUrl: avatarUrl, emailMasked: masked, expired: false));
    }
    _tokens[id] = tokens;
    notifyListeners();
    await _persistTokens(id);
    await _persistIndex();
  }

  /// Yenilenen belirteç çiftini yazar (yalnız listede olan hesap için).
  Future<void> updateTokens(int id, Tokens tokens) async {
    if (!has(id)) return;
    _tokens[id] = tokens;
    await _persistTokens(id);
  }

  /// Gösterim bilgisini günceller (verilen alanlar; boş verilmeyenler korunur).
  Future<void> updateProfile(int id, {String? displayName, String? username, String? avatarUrl, String? email}) async {
    final a = byId(id);
    if (a == null) return;
    final masked = email == null ? null : maskEmail(email);
    final n = a.copyWith(displayName: displayName, username: username, avatarUrl: avatarUrl, emailMasked: masked);
    if (n.displayName == a.displayName && n.username == a.username && n.avatarUrl == a.avatarUrl && n.emailMasked == a.emailMasked) return;
    _replace(n);
    notifyListeners();
    await _persistIndex();
  }

  Future<void> setActive(int? id) async {
    if (_active == id) return;
    _active = id;
    notifyListeners();
    await _persistIndex();
  }

  /// Sunucu oturumu iptal etti: belirteçler silinir, hesap "oturum süresi doldu" olarak listede kalır.
  Future<void> markExpired(int id) async {
    final a = byId(id);
    if (a == null) return;
    _tokens.remove(id);
    _replace(a.copyWith(expired: true));
    notifyListeners();
    await _persistTokens(id);
    await _persistIndex();
  }

  Future<void> remove(int id) async {
    if (!has(id)) return;
    _accounts.removeWhere((a) => a.userId == id);
    _tokens.remove(id);
    if (_active == id) _active = null;
    notifyListeners();
    await _persistTokens(id);
    await _persistIndex();
  }

  Future<void> clear() async {
    final ids = _accounts.map((a) => a.userId).toList();
    _accounts.clear();
    _tokens.clear();
    _active = null;
    notifyListeners();
    for (final id in ids) {
      await _persistTokens(id);
    }
    await _persistIndex();
  }

  /// `ahmet.yilmaz@gmail.com` -> `a***@gmail.com` (ham adres hiçbir yerde saklanmaz).
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return '***';
    return '${email.substring(0, 1)}***${email.substring(at)}';
  }
}
