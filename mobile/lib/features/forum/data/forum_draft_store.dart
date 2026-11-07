import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/swallow.dart';

import '../../../core/secure_store.dart';
import 'forum_compose_rules.dart';

/// Yüklemesi tamamlanmış taslak görseli: yalnız medya kimliği + önizleme adresleri (ham bayt tutulmaz).
class DraftImage {
  const DraftImage({required this.id, required this.url, this.thumbUrl, this.width, this.height});

  final int id;
  final String url;
  final String? thumbUrl;
  final int? width;
  final int? height;

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        if (thumbUrl != null) 'thumb': thumbUrl,
        if (width != null) 'w': width,
        if (height != null) 'h': height,
      };

  static DraftImage? tryParse(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    final url = j['url'];
    if (id is! int || url is! String || url.isEmpty) return null;
    return DraftImage(
      id: id,
      url: url,
      thumbUrl: j['thumb'] as String?,
      width: j['w'] as int?,
      height: j['h'] as int?,
    );
  }
}

/// Yeni konu taslağı.
class ForumDraft {
  const ForumDraft({
    this.title = '',
    this.body = '',
    this.categoryId,
    this.anonymous = false,
    this.images = const [],
    this.poll,
  });

  final String title;
  final String body;
  final int? categoryId;
  final bool anonymous;
  final List<DraftImage> images;
  final PollDraft? poll;

  /// Taslağa değer katan hiçbir şey yok mu (kaydetmeye gerek yok)?
  bool get isEmpty =>
      isBlankText(title) && isBlankText(body) && images.isEmpty && (poll == null || (poll!.filledOptions.isEmpty && isBlankText(poll!.question)));

  Map<String, dynamic> toJson() => {
        'v': 1,
        't': title,
        'b': body,
        if (categoryId != null) 'c': categoryId,
        'a': anonymous,
        'i': [for (final i in images) i.toJson()],
        if (poll != null) 'p': poll!.toJson(),
      };

  static ForumDraft? fromJson(Object? j) {
    if (j is! Map) return null;
    final imgs = j['i'];
    final p = j['p'];
    return ForumDraft(
      title: j['t']?.toString() ?? '',
      body: j['b']?.toString() ?? '',
      categoryId: j['c'] is int ? j['c'] as int : null,
      anonymous: j['a'] == true,
      images: imgs is List
          ? [for (final e in imgs) if (DraftImage.tryParse(e) != null) DraftImage.tryParse(e)!]
          : const [],
      poll: p is Map ? PollDraft.fromJson(Map<String, dynamic>.from(p)) : null,
    );
  }
}

/// Taslak deposu: cihazdaki güvenli depoda (mevcut `FlutterSecureStorage` kalıbı; yeni paket yok) KULLANICIYA özel
/// tek kayıt. Okuma/yazma hataları sessizce yutulur: taslak bir kolaylıktır, yayınlamayı asla engellemez.
class ForumDraftStore {
  ForumDraftStore({FlutterSecureStorage? storage}) : _s = storage ?? kDeviceSecureStorage;

  final FlutterSecureStorage _s;

  @visibleForTesting
  static String keyFor(int? userId) => '$_prefix${userId ?? 0}';

  Future<ForumDraft?> load(int? userId) async {
    try {
      final raw = await _s.read(key: keyFor(userId));
      if (raw == null || raw.isEmpty) return null;
      final d = ForumDraft.fromJson(jsonDecode(raw));
      return d == null || d.isEmpty ? null : d;
    } catch (e) {
      swallow('draft.load', e);
      return null;
    }
  }

  /// Boş taslak yazılmaz (varsa silinir).
  Future<void> save(int? userId, ForumDraft draft) async {
    try {
      if (draft.isEmpty) {
        await clear(userId);
        return;
      }
      await _s.write(key: keyFor(userId), value: jsonEncode(draft.toJson()));
    } catch (e) {
      swallow('draft.save', e);
    }
  }

  Future<void> clear(int? userId) async {
    try {
      await _s.delete(key: keyFor(userId));
    } catch (e) {
      swallow('draft.clear', e);
    }
  }

  /// Çıkış / hesap değişimi / hesap silme: TÜM kullanıcıların taslakları silinir (taslak başlık, metin ve
  /// yüklenmiş görsel adresleri içerir; ortak cihazda kalmamalı. `registerUserDataCleaners` çağırır).
  static Future<void> clearAll({FlutterSecureStorage? storage}) async {
    try {
      final s = storage ?? kDeviceSecureStorage;
      final all = await s.readAll();
      for (final k in all.keys) {
        if (k.startsWith(_prefix)) await s.delete(key: k);
      }
    } catch (e) {
      swallow('draft.clearall', e);
    }
  }

  static const _prefix = 'forum_draft_v1_';
}
