import 'dart:convert';

/// Aktarım yönü: yükleniyor = sunucuya, indiriliyor = cihaza.
enum TransferDirection { upload, download }

/// İş türü (hedefin ne olduğu; çalıştırıcı bu türe göre seçilir).
enum TransferKind { chatMedia, postMedia, forumMedia, download }

/// Durumlar AYRIDIR: dosya aktarıldı != mesaj/gönderi yayımlandı.
/// [published] yalnız SUNUCU sonucu geldikten sonra olur ("Gönderildi/Paylaşıldı" bundan önce denmez).
enum TransferStatus {
  /// Dosya kopyalanıyor / sıkıştırılıyor.
  preparing,

  /// Sırada (eşzamanlı iş sınırı ya da geri çekilme bekleniyor).
  queued,

  /// Baytlar sunucuya gidiyor (ya da cihaza iniyor).
  active,

  /// Ağ yok / zaman aşımı: bağlantı gelince ya da geri çekilme sonunda yeniden denenir.
  waitingNetwork,

  /// Dosya sunucuda; mesaj/gönderi yayımlanması ya da sunucu işlemesi bekleniyor.
  processing,

  /// Sunucu yayımlandığını doğruladı.
  published,

  /// Kalıcı hata ya da deneme hakkı bitti: kullanıcı "Yeniden dene" der.
  failed,

  /// Kullanıcı iptal etti: otomatik başlatılmaz.
  canceled,
}

extension TransferStatusX on TransferStatus {
  bool get isTerminal => this == TransferStatus.published || this == TransferStatus.failed || this == TransferStatus.canceled;

  /// Kuyruk bu işi şu an yürütüyor ya da yürütmeyi bekliyor (kullanıcıya "aktif iş" olarak sayılır).
  bool get isLive => !isTerminal;
}

/// Kuyruğa yeni iş verirken kullanılan istek.
class TransferRequest {
  const TransferRequest({
    required this.ownerUserId,
    required this.kind,
    required this.targetKey,
    required this.sourcePath,
    this.mime = 'application/octet-stream',
    this.totalBytes,
    this.direction = TransferDirection.upload,
    this.meta = const {},
    this.copySource = true,
    this.jobId,
  });

  /// İşi başlatan hesap (G8): hesap değişince iş yeni kimlikle ASLA devam etmez.
  final int ownerUserId;
  final TransferKind kind;

  /// Hedef anahtarı, örn. `conv:42` (sohbet), `post:draft-7`. Yalnız grup/rozet için; gizli veri koymayın.
  final String targetKey;

  /// Yerel kaynak (yükleme) ya da hedef yol (indirme). Yüklemede uygulama dizinine KOPYALANIR.
  final String sourcePath;
  final String mime;

  /// Biliniyorsa toplam bayt; bilinmiyorsa null (yüzde uydurulmaz).
  final int? totalBytes;
  final TransferDirection direction;

  /// Çalıştırıcıya özel küçük JSON alanları (örn. clientId, replyTo). Dosya yolu / mesaj metni koymayın.
  final Map<String, Object?> meta;

  /// false: [sourcePath] zaten uygulama dizinindedir (kopya yapma, iş bitince silinir).
  final bool copySource;

  /// Çağıranın kendi kimliği (idempotent enqueue): aynı kimlikle ikinci enqueue mevcut işi döner.
  final String? jobId;
}

/// Kalıcı iş kaydı (JSON olarak diske yazılır).
class TransferJob {
  TransferJob({
    required this.id,
    required this.ownerUserId,
    required this.kind,
    required this.direction,
    required this.targetKey,
    required this.localPath,
    required this.mime,
    required this.idempotencyKey,
    required this.createdAt,
    this.totalBytes,
    this.doneBytes = 0,
    this.status = TransferStatus.queued,
    this.attempts = 0,
    this.nextAttemptAt,
    this.serverRef,
    this.publishedRef,
    this.lastError,
    this.lastErrorCode,
    this.lastRetryable = true,
    this.osTaskId,
    this.meta = const {},
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  final String id;
  final int ownerUserId;
  final TransferKind kind;
  final TransferDirection direction;
  final String targetKey;
  final String localPath;
  final String mime;

  /// Sunucuya giden `Idempotency-Key`: işin ömrü boyunca SABİT (yeniden denemelerde aynı).
  String idempotencyKey;
  final DateTime createdAt;

  int? totalBytes;
  int doneBytes;
  TransferStatus status;
  int attempts;
  DateTime? nextAttemptAt;

  /// Dosya yükleme aşamasının sunucu kimliği (örn. sohbet ek id'si); yeniden denemede yükleme atlanabilir.
  String? serverRef;

  /// Yayımlanan içeriğin sunucu kimliği (mesaj/gönderi id'si).
  String? publishedRef;
  String? lastError;
  String? lastErrorCode;

  /// Son hata geçici miydi (ağ/5xx/429)? false ise yeniden denemede yeni Idempotency-Key alınır.
  bool lastRetryable;

  /// İşletim sistemi görev kimliği (iOS background URLSession / Android WorkManager); yoksa null.
  String? osTaskId;
  final Map<String, Object?> meta;
  DateTime updatedAt;

  /// 0..1; toplam bilinmiyorsa ya da sunucu işlemesi sırasında null (arayüz belirsiz ilerleme çizer, yüzde YOK).
  double? get fraction {
    final t = totalBytes;
    if (t == null || t <= 0) return null;
    if (status == TransferStatus.processing || status == TransferStatus.published) return status == TransferStatus.published ? 1 : null;
    return (doneBytes / t).clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'owner': ownerUserId,
        'kind': kind.name,
        'dir': direction.name,
        'target': targetKey,
        'path': localPath,
        'mime': mime,
        'idem': idempotencyKey,
        'created': createdAt.millisecondsSinceEpoch,
        'updated': updatedAt.millisecondsSinceEpoch,
        'total': totalBytes,
        'done': doneBytes,
        'status': status.name,
        'attempts': attempts,
        'next': nextAttemptAt?.millisecondsSinceEpoch,
        'server': serverRef,
        'published': publishedRef,
        'err': lastError,
        'errCode': lastErrorCode,
        'retryable': lastRetryable,
        'os': osTaskId,
        'meta': meta,
      };

  /// Bozuk kayıtta null döner (kuyruk o kaydı atlar, çökmez).
  static TransferJob? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      T pick<T extends Enum>(List<T> values, Object? v, T fallback) {
        for (final e in values) {
          if (e.name == v) return e;
        }
        return fallback;
      }

      final id = raw['id'];
      final path = raw['path'];
      final owner = raw['owner'];
      if (id is! String || path is! String || owner is! num) return null;
      DateTime ms(Object? v) => DateTime.fromMillisecondsSinceEpoch((v as num?)?.toInt() ?? 0);
      return TransferJob(
        id: id,
        ownerUserId: owner.toInt(),
        kind: pick(TransferKind.values, raw['kind'], TransferKind.chatMedia),
        direction: pick(TransferDirection.values, raw['dir'], TransferDirection.upload),
        targetKey: (raw['target'] as String?) ?? '',
        localPath: path,
        mime: (raw['mime'] as String?) ?? 'application/octet-stream',
        idempotencyKey: (raw['idem'] as String?) ?? id,
        createdAt: ms(raw['created']),
        updatedAt: ms(raw['updated']),
        totalBytes: (raw['total'] as num?)?.toInt(),
        doneBytes: (raw['done'] as num?)?.toInt() ?? 0,
        status: pick(TransferStatus.values, raw['status'], TransferStatus.failed),
        attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
        nextAttemptAt: raw['next'] == null ? null : ms(raw['next']),
        serverRef: raw['server'] as String?,
        publishedRef: raw['published'] as String?,
        lastError: raw['err'] as String?,
        lastErrorCode: raw['errCode'] as String?,
        lastRetryable: raw['retryable'] != false,
        osTaskId: raw['os'] as String?,
        meta: raw['meta'] is Map ? Map<String, Object?>.from(raw['meta'] as Map) : const {},
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// TEK ortak ilerleme kaynağından türeyen özet: sohbet, Aktarımlar alanı ve sistem bildirimi aynı sayıları kullanır.
class TransferSummary {
  const TransferSummary({
    this.active = 0,
    this.waiting = 0,
    this.processing = 0,
    this.failed = 0,
    this.doneBytes = 0,
    this.totalBytes,
  });

  /// Bayt gönderen ya da sırada bekleyen canlı iş sayısı (yayımlanan/iptal/başarısız hariç).
  final int active;

  /// Ağ bekleyen iş sayısı.
  final int waiting;

  /// Dosyası gitmiş, sunucu sonucu beklenen iş sayısı.
  final int processing;
  final int failed;
  final int doneBytes;

  /// Canlı işlerin HEPSİNİN toplamı biliniyorsa toplam; biri bile bilinmiyorsa null.
  final int? totalBytes;

  int get liveCount => active + waiting + processing;
  bool get isIdle => liveCount == 0 && failed == 0;

  /// Toplam bilinmiyorsa null: yüzde uydurulmaz (belirsiz ilerleme çizilir).
  double? get fraction {
    final t = totalBytes;
    if (t == null || t <= 0 || active == 0) return null;
    return (doneBytes / t).clamp(0.0, 1.0);
  }

  static TransferSummary of(Iterable<TransferJob> jobs) {
    var active = 0, waiting = 0, processing = 0, failed = 0, done = 0;
    int? total = 0;
    for (final j in jobs) {
      switch (j.status) {
        case TransferStatus.preparing:
        case TransferStatus.queued:
        case TransferStatus.active:
          active++;
          done += j.doneBytes;
          final t = j.totalBytes;
          total = (t == null || t <= 0 || total == null) ? null : total + t;
        case TransferStatus.waitingNetwork:
          waiting++;
        case TransferStatus.processing:
          processing++;
        case TransferStatus.failed:
          failed++;
        case TransferStatus.published:
        case TransferStatus.canceled:
          break;
      }
    }
    return TransferSummary(
        active: active, waiting: waiting, processing: processing, failed: failed, doneBytes: done, totalBytes: active == 0 ? null : total);
  }

  @override
  bool operator ==(Object other) =>
      other is TransferSummary &&
      other.active == active &&
      other.waiting == waiting &&
      other.processing == processing &&
      other.failed == failed &&
      other.doneBytes == doneBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode => Object.hash(active, waiting, processing, failed, doneBytes, totalBytes);
}
