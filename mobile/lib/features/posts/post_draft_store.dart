import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/secure_store.dart';
import '../../core/swallow.dart';

/// Gönderi metni taslağı (I2-05): yalnız metin + etiketlenen kişiler (kimlik/ad); fotoğraf/video taslağa girmez
/// (yeniden seçilir). KULLANICIYA özel anahtar: başka hesapta görünmez.
class PostDraft {
  const PostDraft({this.text = '', this.mentions = const []});

  final String text;

  /// `{id, name}` çiftleri.
  final List<({int id, String name})> mentions;

  bool get isEmpty => text.trim().isEmpty;

  Map<String, Object?> toJson() => {
        't': text,
        'm': [for (final m in mentions) {'i': m.id, 'n': m.name}],
      };

  static PostDraft? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['t'];
    if (t is! String) return null;
    final ms = <({int id, String name})>[];
    final l = raw['m'];
    if (l is List) {
      for (final e in l) {
        if (e is Map && e['i'] is num && e['n'] is String) ms.add((id: (e['i'] as num).toInt(), name: e['n'] as String));
      }
    }
    return PostDraft(text: t, mentions: ms);
  }
}

/// Güvenli depoda (mevcut `FlutterSecureStorage` kalıbı; yeni paket yok) kullanıcı başına tek taslak. Hatalar yutulur:
/// taslak bir kolaylıktır, paylaşmayı asla engellemez. Çıkış / hesap değişimi / silme: [clearAll]
/// (`registerUserDataCleaners`). Başarıyla kuyruğa alınınca ya da kullanıcı "At" deyince [clear].
class PostDraftStore {
  PostDraftStore({FlutterSecureStorage? storage}) : _s = storage ?? kDeviceSecureStorage;

  final FlutterSecureStorage _s;

  static const _prefix = 'post_draft_v1_';

  @visibleForTesting
  static String keyFor(int? userId) => '$_prefix${userId ?? 0}';

  Future<PostDraft?> load(int? userId) async {
    if (userId == null) return null; // kimliksiz oturumda taslak tutulmaz (hesaplar karışmasın)
    try {
      final raw = await _s.read(key: keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      final d = PostDraft.fromJson(jsonDecode(raw));
      return d == null || d.isEmpty ? null : d;
    } catch (e) {
      swallow('postdraft.load', e);
      return null;
    }
  }

  /// Boş taslak yazılmaz (varsa silinir).
  Future<void> save(int? userId, PostDraft draft) async {
    if (userId == null) return;
    try {
      if (draft.isEmpty) {
        await clear(userId);
        return;
      }
      await _s.write(key: keyFor(userId), value: jsonEncode(draft.toJson()));
    } catch (e) {
      swallow('postdraft.save', e);
    }
  }

  Future<void> clear(int? userId) async {
    if (userId == null) return;
    try {
      await _s.delete(key: keyFor(userId));
    } catch (e) {
      swallow('postdraft.clear', e);
    }
  }

  /// Tüm kullanıcıların taslakları (ortak cihazda kalmasın).
  static Future<void> clearAll({FlutterSecureStorage? storage}) async {
    try {
      final s = storage ?? kDeviceSecureStorage;
      final all = await s.readAll();
      for (final k in all.keys) {
        if (k.startsWith(_prefix)) await s.delete(key: k);
      }
    } catch (e) {
      swallow('postdraft.clearall', e);
    }
  }
}
