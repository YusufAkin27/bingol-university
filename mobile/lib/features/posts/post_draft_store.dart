import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../chat/media_pick.dart';

/// Kaydedilmiş gönderi taslağı: metin + medya dosya yolları (24 saat geçerli).
class PostDraft {
  PostDraft({required this.text, required this.items, required this.savedAt});

  final String text;
  final List<DraftMedia> items;
  final DateTime savedAt;

  bool get isEmpty => text.trim().isEmpty && items.isEmpty;
}

class DraftMedia {
  const DraftMedia({required this.key, required this.isVideo, required this.durationMs, required this.path});
  final String key;
  final bool isVideo;
  final int durationMs;
  final String path;

  Map<String, Object?> toJson() => {'key': key, 'video': isVideo, 'ms': durationMs, 'path': path};

  /// Dosya yoksa null (temizlenmiş / taşınmış).
  MediaPick? toPick() {
    final f = File(path);
    if (!f.existsSync()) return null;
    if (isVideo) {
      return MediaPick(
        key: key,
        isVideo: true,
        durationMs: durationMs,
        thumb: (_) async => null,
        videoPath: () async => path,
      );
    }
    return MediaPick(
      key: key,
      isVideo: false,
      thumb: (_) async => f.readAsBytesSync(),
      imageBytes: () async => f.readAsBytesSync(),
    );
  }
}

/// Taslağı güvenli yerel depoda (flutter_secure_storage) kullanıcı başına saklar.
/// Fotoğraf baytları yoldan okunabilsin diye geçici dosyaya yazılır.
class PostDraftStore {
  PostDraftStore({FlutterSecureStorage? storage, this.ttl = const Duration(hours: 24)})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Duration ttl;

  static String _key(int? userId) => 'post_draft_${userId ?? 0}';

  Future<PostDraft?> load(int? userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt());
      if (DateTime.now().difference(at) > ttl) {
        await clear(userId);
        return null;
      }
      final items = <DraftMedia>[
        for (final e in (j['items'] as List? ?? const []))
          if (e is Map)
            DraftMedia(
              key: '${e['key']}',
              isVideo: e['video'] == true,
              durationMs: (e['ms'] as num?)?.toInt() ?? 0,
              path: '${e['path']}',
            ),
      ];
      final d = PostDraft(text: (j['text'] as String?) ?? '', items: items, savedAt: at);
      return d.isEmpty ? null : d;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(int? userId, PostDraft d) async {
    try {
      if (d.isEmpty) return await clear(userId);
      await _storage.write(
        key: _key(userId),
        value: jsonEncode({
          'text': d.text,
          'at': d.savedAt.millisecondsSinceEpoch,
          'items': [for (final i in d.items) i.toJson()],
        }),
      );
    } catch (_) {}
  }

  Future<void> clear(int? userId) async {
    try {
      await _storage.delete(key: _key(userId));
    } catch (_) {}
  }

  /// Seçili öğeyi taslak için diske yazar (video zaten dosyadır). Başarısızsa null.
  Future<DraftMedia?> materialize(MediaPick p) async {
    try {
      if (p.isVideo) {
        final path = await p.videoPath?.call();
        if (path == null) return null;
        return DraftMedia(key: p.key, isVideo: true, durationMs: p.durationMs, path: path);
      }
      final Uint8List? bytes = await p.imageBytes?.call();
      if (bytes == null) return null;
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}bu_post_draft');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final name = 'd_${p.key.hashCode.abs()}_${bytes.length}.img';
      final f = File('${dir.path}${Platform.pathSeparator}$name');
      if (!f.existsSync()) f.writeAsBytesSync(bytes, flush: true);
      return DraftMedia(key: p.key, isVideo: false, durationMs: 0, path: f.path);
    } catch (_) {
      return null;
    }
  }
}
