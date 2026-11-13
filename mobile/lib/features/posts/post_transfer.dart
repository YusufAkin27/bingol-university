import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;

import '../../core/api.dart';
import '../../core/platform/image_service.dart' show ImageException;
import '../../core/platform/video_service.dart';
import '../../core/session.dart';
import '../../core/transfers/transfer_executor.dart';
import '../../core/transfers/transfer_hub.dart';
import '../../core/transfers/transfer_job.dart';
import '../../core/transfers/transfer_queue.dart';
import '../../l10n/app_localizations.dart';
import 'post_api.dart';
import 'post_media_uploader.dart';

/// Gönderi aktarımlarının hedef anahtarı (rozet/liste süzgeci).
const String kPostTransferTarget = 'post:feed';

/// Oluşturucu kapanış sonucu: paylaşım aktarım kuyruğuna alındı (gönderi henüz yok; sunucuda yayımlanınca görünür).
class PostQueued {
  const PostQueued(this.jobId);
  final String jobId;
}

class PostPhotoRef {
  const PostPhotoRef(this.file, this.aspect);
  final String file;
  final double aspect;
}

class PostVideoRef {
  const PostVideoRef({required this.file, this.poster, required this.durationMs, this.width, this.height, required this.size});
  final String file;
  final String? poster;
  final int durationMs;
  final int? width, height;
  final int size;
}

class PostMentionRef {
  const PostMentionRef(this.id, this.name, [this.avatarUrl]);
  final int id;
  final String name;
  final String? avatarUrl;
}

/// Kuyruktaki bir gönderinin içeriği: iş dizinindeki `post.json` (metin burada, kuyruk meta'sında DEĞİL) + medya dosyaları.
/// Dizin iş bitince/silinince kuyruk tarafından tamamen silinir.
class PostPayload {
  const PostPayload({
    this.text = '',
    this.mentions = const [],
    this.hideLikes = false,
    this.commentsOff = false,
    this.photos = const [],
    this.video,
  });

  final String text;
  final List<PostMentionRef> mentions;
  final bool hideLikes, commentsOff;
  final List<PostPhotoRef> photos;
  final PostVideoRef? video;

  static const fileName = 'post.json';

  Map<String, Object?> toJson() => {
        'v': 1,
        'text': text,
        'mentions': [for (final m in mentions) {'id': m.id, 'name': m.name, 'avatar': m.avatarUrl}],
        'hideLikes': hideLikes,
        'commentsOff': commentsOff,
        'photos': [for (final p in photos) {'file': p.file, 'aspect': p.aspect}],
        if (video != null)
          'video': {
            'file': video!.file,
            'poster': video!.poster,
            'durationMs': video!.durationMs,
            'width': video!.width,
            'height': video!.height,
            'size': video!.size,
          },
      };

  static PostPayload fromJson(Map<String, dynamic> j) {
    final v = j['video'];
    return PostPayload(
      text: (j['text'] as String?) ?? '',
      mentions: [
        for (final m in (j['mentions'] as List? ?? const []))
          if (m is Map && m['id'] is num) PostMentionRef((m['id'] as num).toInt(), (m['name'] as String?) ?? '', m['avatar'] as String?),
      ],
      hideLikes: j['hideLikes'] == true,
      commentsOff: j['commentsOff'] == true,
      photos: [
        for (final p in (j['photos'] as List? ?? const []))
          if (p is Map && p['file'] is String) PostPhotoRef(p['file'] as String, (p['aspect'] as num?)?.toDouble() ?? 0.8),
      ],
      video: v is Map && v['file'] is String
          ? PostVideoRef(
              file: v['file'] as String,
              poster: v['poster'] as String?,
              durationMs: (v['durationMs'] as num?)?.toInt() ?? 0,
              width: (v['width'] as num?)?.toInt(),
              height: (v['height'] as num?)?.toInt(),
              size: (v['size'] as num?)?.toInt() ?? 0,
            )
          : null,
    );
  }

  static Future<PostPayload> read(Directory dir) async {
    final raw = await File('${dir.path}${Platform.pathSeparator}$fileName').readAsString();
    return fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  /// İş dizini (`TransferJob.localPath` ilk medya dosyasıdır; aynı dizindedir).
  static Directory dirOf(TransferJob job) => File(job.localPath).parent;
}

/// Gönderiyi kuyruğa alır: medya + metin iş dizinine yazılır (seçicinin geçici dosyası kaybolsa da iş sürer), kuyruk işi
/// ekran kapansa da yürütür. Dönen iş `published` olunca (sunucu gönderiyi oluşturunca) gönderi VARDIR; öncesinde
/// başka kullanıcılara hiçbir şey görünmez (sunucu gönderiyi yalnız yükleme tamamlanınca oluşturur).
Future<TransferJob> enqueuePostTransfer(
  TransferQueue q, {
  required int ownerUserId,
  String text = '',
  List<PostMentionRef> mentions = const [],
  bool hideLikes = false,
  bool commentsOff = false,
  List<({Uint8List bytes, double aspect})> photos = const [],
  PreparedVideo? video,
}) async {
  assert(photos.isNotEmpty || video != null, 'en az bir medya gerekir');
  final id = 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  final dir = Directory('${(await q.store.filesDir()).path}${Platform.pathSeparator}$id');
  await dir.create(recursive: true);
  String p(String n) => '${dir.path}${Platform.pathSeparator}$n';
  try {
    final refs = <PostPhotoRef>[];
    PostVideoRef? vref;
    var total = 0;
    String first;
    if (video != null) {
      final out = File(p('video.mp4'));
      final src = video.path;
      if (src != null) {
        await File(src).copy(out.path);
      } else {
        await out.writeAsBytes(video.bytes!);
      }
      String? poster;
      final pb = video.poster;
      if (pb != null && pb.isNotEmpty) {
        await File(p('poster.jpg')).writeAsBytes(pb);
        poster = 'poster.jpg';
      }
      total = await out.length();
      vref = PostVideoRef(
          file: 'video.mp4', poster: poster, durationMs: video.durationMs, width: video.width, height: video.height, size: total);
      first = out.path;
    } else {
      for (var i = 0; i < photos.length; i++) {
        final f = File(p('photo$i.img'));
        await f.writeAsBytes(photos[i].bytes);
        total += photos[i].bytes.length;
        refs.add(PostPhotoRef('photo$i.img', photos[i].aspect));
      }
      first = p('photo0.img');
    }
    await File(p(PostPayload.fileName)).writeAsString(jsonEncode(PostPayload(
      text: text,
      mentions: mentions,
      hideLikes: hideLikes,
      commentsOff: commentsOff,
      photos: refs,
      video: vref,
    ).toJson()));
    return await q.enqueue(TransferRequest(
      ownerUserId: ownerUserId,
      kind: TransferKind.postMedia,
      targetKey: kPostTransferTarget,
      sourcePath: first,
      mime: video != null ? 'video/mp4' : 'image/jpeg',
      totalBytes: total,
      meta: {'photos': refs.length, 'video': video != null},
      copySource: false,
      jobId: id,
    ));
  } catch (_) {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // Bilerek yutulur: en iyi çaba.
    }
    rethrow;
  }
}

/// Gönderi çalıştırıcısı: (1) medya `POST /posts/media` (video: `file`+`poster`), (2) `POST /posts`; ikisi de iş
/// anahtarını `Idempotency-Key` olarak taşır (çoklu fotoğrafta her ek için `<anahtar>-m<i>`). Yüklenen medya kimlikleri
/// `serverRef`te (virgüllü) kalıcıdır: yeniden denemede yüklenenler atlanır. "Yayımlandı" yalnız `POST /posts` yanıtı
/// gelince döner.
class PostTransferExecutor extends TransferExecutor {
  PostTransferExecutor(this.session, {PostMediaUploader? photos, VideoUploader? videos, PostApi? api})
      : _photos = photos ?? PostMediaUploader(session),
        _videos = videos ?? VideoUploader(session),
        _api = api ?? PostApi(session);

  final Session session;
  final PostMediaUploader _photos;
  final VideoUploader _videos;
  final PostApi _api;

  static List<int> _refIds(TransferJob j) =>
      [for (final s in (j.serverRef ?? '').split(',')) if (int.tryParse(s) != null) int.parse(s)];

  /// Hataları kuyruğun sınıflandırabileceği biçime çevirir (kod -> kullanıcı metni için [postFailureText]).
  static TransferFailure wrap(Object e) {
    if (e is TransferFailure) return e;
    if (e is ImageException) return TransferFailure('IMG_${e.code}', retryable: false);
    if (e is VideoException) return TransferFailure('VID_${e.code}', retryable: false);
    if (e is ApiError) {
      if (e.status == 429) return TransferFailure('RATE_LIMITED', message: e.message);
      if (e.status == 0) return TransferFailure('NETWORK', network: true);
    }
    return TransferFailure.fromError(e);
  }

  @override
  Future<String> run(TransferJob job, TransferRunContext ctx) async {
    final PostPayload pay;
    try {
      pay = await PostPayload.read(PostPayload.dirOf(job));
    } catch (_) {
      throw const TransferFailure('FILES_MISSING', retryable: false);
    }
    final dir = PostPayload.dirOf(job).path;
    final ids = _refIds(job);
    final total = job.totalBytes;
    try {
      final v = pay.video;
      if (v != null) {
        if (ids.isEmpty) {
          final size = v.size > 0 ? v.size : (total ?? 0);
          final pv = PreparedVideo(
            path: '$dir${Platform.pathSeparator}${v.file}',
            sizeBytes: size,
            durationMs: v.durationMs,
            width: v.width,
            height: v.height,
            poster: v.poster == null ? null : await File('$dir${Platform.pathSeparator}${v.poster}').readAsBytes(),
          );
          final json = await _videos.upload(PostMediaUploader.path, pv,
              headers: {'Idempotency-Key': '${job.idempotencyKey}-m0'},
              onProgress: (f) => ctx.progress((f * size).round(), size));
          if (json is! Map) throw ApiError(500, 'BAD_RESPONSE', '');
          final m = json['media'] is Map ? json['media'] as Map : json;
          final id = m['id'];
          if (id is! num) throw ApiError(500, 'BAD_RESPONSE', '');
          ids.add(id.toInt());
          ctx.setServerRef(ids.join(','));
        }
      } else {
        var done = 0;
        for (var i = 0; i < ids.length && i < pay.photos.length; i++) {
          done += await File('$dir${Platform.pathSeparator}${pay.photos[i].file}').length();
        }
        for (var i = ids.length; i < pay.photos.length; i++) {
          if (ctx.canceled) throw const TransferFailure('CANCELED', retryable: false);
          final f = File('$dir${Platform.pathSeparator}${pay.photos[i].file}');
          final bytes = await f.readAsBytes();
          final m = await _photos.uploadWith(bytes, headers: {'Idempotency-Key': '${job.idempotencyKey}-m$i'});
          ids.add(m.id);
          ctx.setServerRef(ids.join(','));
          done += bytes.length;
          ctx.progress(done, total);
        }
      }
    } catch (e) {
      throw wrap(e);
    }
    if (ctx.canceled) {
      await discard(job..serverRef = ids.join(','));
      throw const TransferFailure('CANCELED', retryable: false);
    }
    ctx.markProcessing(); // medya sunucuda; gönderi oluşturulana dek "Paylaşılıyor"
    try {
      final post = await _api.create(
        text: pay.text,
        mediaIds: ids,
        mentionUserIds: [for (final m in pay.mentions) m.id],
        hideLikeCount: pay.hideLikes,
        commentsDisabled: pay.commentsOff,
        idempotencyKey: job.idempotencyKey,
      );
      return '${post.id}';
    } catch (e) {
      if (e is ApiError && e.code == 'POST_MEDIA_INVALID') {
        // Yüklenen medya süresi dolmuş/geçersiz: bir sonraki denemede yeniden yüklenir.
        ctx.setServerRef('');
        throw const TransferFailure('POST_MEDIA_INVALID');
      }
      throw wrap(e);
    }
  }

  /// İptal / hesap çıkışı: gönderiye bağlanmamış yüklenmiş medyayı sil (gönderi yoksa sahibi silebilir). Hata sızdırmaz.
  @override
  Future<void> discard(TransferJob job) async {
    for (final id in _refIds(job)) {
      try {
        await session.api.delete('/posts/media/$id');
      } catch (_) {
        // Bilerek yutulur: yetim medya sunucuda gece süpürülür.
      }
    }
  }
}

/// Çalıştırıcıyı kuyruk merkezine kaydeder (main'de oturumdan önce bir kez; yarım kalan işler açılışta sürsün).
void registerPostTransfer() {
  TransferHub.instance.addExecutor(TransferKind.postMedia, (s) => PostTransferExecutor(s));
}

/// Başarısız gönderi işinin kullanıcıya gösterilecek nedeni (kayıtlı hata koduna göre).
String postFailureText(TransferJob job, AppLocalizations l) {
  final code = job.lastErrorCode ?? '';
  if (code == 'FILES_MISSING' || code == 'SOURCE_MISSING') return l.g2PostErrFiles;
  final Object e;
  if (code.startsWith('IMG_')) {
    e = ImageException(code.substring(4));
  } else if (code.startsWith('VID_')) {
    e = VideoException(code.substring(4));
  } else if (code == 'NETWORK') {
    e = ApiError(0, 'NETWORK', '');
  } else if (code == 'RATE_LIMITED') {
    e = ApiError(429, code, '');
  } else {
    e = ApiError(job.lastRetryable ? 503 : 400, code, '');
  }
  return postErrorText(e, l);
}

/// Bekleyen (canlı ya da başarısız) gönderi işleri: kabuk/ekranlar rozet için kullanır.
int livePostTransfers() {
  final q = TransferHub.instance.queue;
  if (q == null) return 0;
  return q.jobsFor(targetKey: kPostTransferTarget).where((j) => j.status.isLive).length;
}
