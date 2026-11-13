import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../idempotency_key.dart';
import 'transfer_executor.dart';
import 'transfer_job.dart';
import 'transfer_platform.dart';
import 'transfer_store.dart';

typedef TransferDelay = Duration Function(int attempt);

/// Kalıcı aktarım kuyruğu: sohbet / gönderi / forum medya yüklemelerinin TEK ortak ilerleme ve durum kaynağı.
///
/// Sözleşme (özet; ayrıntı docs/changes/transfers.md):
///  - [enqueue] kaynak dosyayı uygulama dizinine kopyalar, kaydı diske yazar; iş ekran/sohbet kapansa da sürer.
///  - Her iş tek `Idempotency-Key` taşır (yeniden denemede aynı); sunucu ikinci kaydı yutar.
///  - "Yayımlandı" YALNIZ çalıştırıcı sunucu sonucunu döndürünce olur.
///  - Açılışta ([start]) yürütülürken ölen işler sırada başa döner; kullanıcı iptali ve yayımlananlar yeniden başlatılmaz.
///  - Hesap: yalnız [start]'ta verilen sahibin işleri yürür; [signOut] sahibin işlerini durdurur ve dosyalarını siler.
class TransferQueue {
  TransferQueue({
    required this.store,
    TransferPlatform? platform,
    this.labels = const TransferLabels(),
    this.maxConcurrent = 2,
    this.maxAttempts = 6,
    TransferDelay? backoff,
    DateTime Function()? now,
    this.emitInterval = const Duration(milliseconds: 120),
  })  : platform = platform ?? const NoopTransferPlatform(),
        _backoff = backoff ?? defaultBackoff,
        _now = now ?? DateTime.now;

  final TransferStore store;
  final TransferPlatform platform;
  TransferLabels labels;
  final int maxConcurrent;
  final int maxAttempts;
  final Duration emitInterval;
  final TransferDelay _backoff;
  final DateTime Function() _now;

  final Map<TransferKind, TransferExecutor> _executors = {};
  final List<TransferJob> _jobs = [];
  final Set<String> _running = {};
  final Set<String> _cancelFlags = {};
  final _jobCtl = StreamController<List<TransferJob>>.broadcast();
  final _sumCtl = StreamController<TransferSummary>.broadcast();
  TransferSummary _lastSummary = const TransferSummary();
  Timer? _emitTimer;
  Timer? _wakeTimer;
  int? _owner;
  bool _started = false;
  Future<void> _saving = Future.value();

  /// 2 sn, 4 sn, 8 sn ... en çok 5 dk; +-%20 sapma (hepsi aynı anda yüklenmesin).
  static Duration defaultBackoff(int attempt) {
    final base = math.min(300, 2 * math.pow(2, math.max(0, attempt - 1)).toInt());
    final jitter = 0.8 + math.Random().nextDouble() * 0.4;
    return Duration(milliseconds: (base * 1000 * jitter).round());
  }

  int? get owner => _owner;
  List<TransferJob> get jobs => List.unmodifiable(_jobs);
  TransferSummary get summary => _lastSummary;

  void registerExecutor(TransferKind kind, TransferExecutor executor) {
    _executors[kind] = executor;
    _pump();
  }

  /// Sahibin işleri (en yeni önce); [targetKey] verilirse yalnız o hedefin işleri (örn. `conv:42`).
  List<TransferJob> jobsFor({String? targetKey}) {
    final o = _owner;
    final out = [for (final j in _jobs) if (j.ownerUserId == o && (targetKey == null || j.targetKey == targetKey)) j];
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// İş listesi akışı (ilk değer hemen gelir). Bayt ilerlemesi [emitInterval] ile seyrekleştirilir.
  Stream<List<TransferJob>> watch({String? targetKey}) async* {
    yield jobsFor(targetKey: targetKey);
    yield* _jobCtl.stream.map((_) => jobsFor(targetKey: targetKey));
  }

  Stream<TransferJob?> watchJob(String id) async* {
    yield job(id);
    yield* _jobCtl.stream.map((_) => job(id));
  }

  /// Sohbet / Aktarımlar alanı / bildirim aynı özeti okur.
  Stream<TransferSummary> watchSummary() async* {
    yield _lastSummary;
    yield* _sumCtl.stream;
  }

  TransferJob? job(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  // ---------------------------------------------------------------- yaşam döngüsü

  /// Oturum açılınca: kayıtları yükler, başka hesabın artıklarını siler, yarım kalanları kurtarır, çalıştırır.
  Future<void> start(int ownerUserId) async {
    _owner = ownerUserId;
    if (!_started) {
      _started = true;
      _jobs
        ..clear()
        ..addAll(await store.load());
    }
    // Başka hesabın işi yeni kimlikle devam ETMEZ: durdurulur, dosyası silinir.
    final foreign = [for (final j in _jobs) if (j.ownerUserId != ownerUserId) j];
    for (final j in foreign) {
      await _drop(j, discardServer: false);
    }
    final dayAgo = _now().subtract(const Duration(hours: 24));
    for (final j in List.of(_jobs)) {
      if (j.status.isTerminal && j.updatedAt.isBefore(dayAgo)) await _drop(j, discardServer: false);
    }
    for (final j in _jobs) {
      // Süreç ölünce yürütülüyordu: sunucu sonucu bilinmiyor -> sırada başa döner. Aynı Idempotency-Key ile gönderildiği
      // için dosya sunucuya ulaşmışsa ikinci kayıt oluşmaz; kullanıcı iptali ve sonlanmışlar dokunulmaz.
      if (j.status == TransferStatus.preparing || j.status == TransferStatus.active || j.status == TransferStatus.processing) {
        j.status = TransferStatus.queued;
        j.doneBytes = 0;
      }
    }
    await _persist();
    _emit(urgent: true);
    _pump();
  }

  /// Çıkış / hesap silme: sahibin tüm işleri durdurulur, sunucudaki yayımlanmamış kalıntı silinir, yerel dosyalar silinir.
  Future<void> signOut() async {
    final o = _owner;
    for (final j in List.of(_jobs)) {
      if (j.ownerUserId == o) {
        await _drop(j, discardServer: j.status.isLive);
      }
    }
    // Çıkış sürerken yeni hesap girdiyse (start _owner'ı değiştirdi) onun sahipliğini ve zamanlayıcısını bozma.
    if (_owner == o) {
      _owner = null;
      _wakeTimer?.cancel();
    }
    await _persist();
    _emit(urgent: true);
  }

  /// Bağlantı geri gelince ya da uygulama öne gelince: bekleyen işlerin geri çekilmesini atla.
  void nudge() {
    for (final j in _jobs) {
      if (j.ownerUserId == _owner && j.status == TransferStatus.waitingNetwork) {
        j.status = TransferStatus.queued;
        j.nextAttemptAt = null;
      }
    }
    _emit(urgent: true);
    _pump();
  }

  // ---------------------------------------------------------------- kullanıcı eylemleri

  Future<TransferJob> enqueue(TransferRequest r) async {
    final owner = _owner;
    if (owner == null || owner != r.ownerUserId) {
      throw StateError('Aktarım sahibi geçerli hesapla eşleşmiyor');
    }
    final dupId = r.jobId;
    if (dupId != null) {
      final existing = job(dupId);
      if (existing != null) return existing;
    }
    final id = dupId ?? newIdempotencyKey('t');
    var path = r.sourcePath;
    var total = r.totalBytes;
    if (r.direction == TransferDirection.upload) {
      final dir = Directory('${(await store.filesDir()).path}${Platform.pathSeparator}$id');
      await dir.create(recursive: true);
      final src = File(r.sourcePath);
      if (r.copySource) {
        // Seçicinin geçici dosyası/izni kaybolsa da iş sürsün: kendi kopyamızdan yüklenir.
        final dst = File('${dir.path}${Platform.pathSeparator}${_safeName(r.sourcePath)}');
        await src.copy(dst.path);
        path = dst.path;
      }
      total ??= await File(path).length();
    }
    final job0 = TransferJob(
      id: id,
      ownerUserId: owner,
      kind: r.kind,
      direction: r.direction,
      targetKey: r.targetKey,
      localPath: path,
      mime: r.mime,
      idempotencyKey: newIdempotencyKey('x'),
      createdAt: _now(),
      totalBytes: total,
      meta: r.meta,
    );
    _jobs.add(job0);
    await _persist();
    _emit(urgent: true);
    _pump();
    return job0;
  }

  /// Kullanıcı iptali: yürüyen iş durdurulur, otomatik başlatılmaz. Yayımlanmış iş iptal edilemez (false).
  Future<bool> cancel(String id) async {
    final j = job(id);
    if (j == null || j.status.isTerminal) return false;
    _cancelFlags.add(id);
    final hadServer = j.serverRef != null;
    j.status = TransferStatus.canceled;
    j.updatedAt = _now();
    if (hadServer) await _discard(j);
    await _deleteFiles(j);
    await _persist();
    _emit(urgent: true);
    _pump();
    return true;
  }

  /// "Yeniden dene": hata/iptal sonrası. Kalıcı reddi ya da iptal edilen işte YENİ Idempotency-Key alınır
  /// (sunucuda silinmiş kalıntıya eski anahtarla yeniden oynatılmasın); geçici hatada aynı anahtar korunur.
  /// İptalde yerel kopya silindiği için yeniden denenemez (false): çağıran dosyayı yeniden seçtirir.
  Future<bool> retry(String id) async {
    final j = job(id);
    if (j == null || j.ownerUserId != _owner) return false;
    if (j.status != TransferStatus.failed) return false;
    if (j.direction == TransferDirection.upload && !File(j.localPath).existsSync()) return false;
    if (!j.lastRetryable) {
      j.idempotencyKey = newIdempotencyKey('x');
      j.serverRef = null;
    }
    _cancelFlags.remove(id);
    j.status = TransferStatus.queued;
    j.attempts = 0;
    j.nextAttemptAt = null;
    j.lastError = null;
    j.lastErrorCode = null;
    j.doneBytes = 0;
    j.updatedAt = _now();
    await _persist();
    _emit(urgent: true);
    _pump();
    return true;
  }

  /// Sonlanmış (yayımlandı / hata / iptal) kaydı listeden kaldırır; yayımlanmış sunucu içeriğine dokunmaz.
  Future<void> dismiss(String id) async {
    final j = job(id);
    if (j == null || !j.status.isTerminal) return;
    await _drop(j, discardServer: false);
    await _persist();
    _emit(urgent: true);
  }

  // ---------------------------------------------------------------- yürütme

  void _pump() {
    if (!_started || _owner == null) return;
    final now = _now();
    DateTime? nextWake;
    final due = <TransferJob>[];
    for (final j in _jobs) {
      if (j.ownerUserId != _owner) continue;
      if (j.status != TransferStatus.queued && j.status != TransferStatus.waitingNetwork) continue;
      if (_running.contains(j.id)) continue;
      if (!_executors.containsKey(j.kind)) continue; // çalıştırıcı kaydı gelince registerExecutor yeniden tetikler
      final at = j.nextAttemptAt;
      if (at != null && at.isAfter(now)) {
        if (nextWake == null || at.isBefore(nextWake)) nextWake = at;
        continue;
      }
      due.add(j);
    }
    due.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final j in due) {
      if (_running.length >= maxConcurrent) break;
      _running.add(j.id);
      unawaited(_run(j));
    }
    _wakeTimer?.cancel();
    if (nextWake != null) {
      final d = nextWake.difference(now);
      _wakeTimer = Timer(d.isNegative ? Duration.zero : d, _pump);
    }
  }

  Future<void> _run(TransferJob j) async {
    try {
      final ex = _executors[j.kind];
      if (ex == null) return; // _pump zaten elemiştir; savunma
      if (j.direction == TransferDirection.upload && !File(j.localPath).existsSync()) {
        await _fail(j, const TransferFailure('SOURCE_MISSING', retryable: false));
        return;
      }
      j.status = TransferStatus.active;
      j.attempts++;
      j.nextAttemptAt = null;
      j.updatedAt = _now();
      await _persist();
      _emit(urgent: true);
      final ctx = _Ctx(this, j);
      try {
        final ref = await ex.run(j, ctx);
        await _finish(j, ref);
      } catch (e) {
        if (_cancelFlags.contains(j.id) && j.status == TransferStatus.canceled) return;
        await _fail(j, TransferFailure.fromError(e));
      }
    } finally {
      _running.remove(j.id);
      _cancelFlags.remove(j.id);
      _pump();
    }
  }

  Future<void> _finish(TransferJob j, String publishedRef) async {
    // Sunucu yayımlandığını doğruladı: iptal yarışı olsa bile gerçek durum "yayımlandı".
    j.status = TransferStatus.published;
    j.publishedRef = publishedRef;
    j.doneBytes = j.totalBytes ?? j.doneBytes;
    j.lastError = null;
    j.lastErrorCode = null;
    j.updatedAt = _now();
    await _deleteFiles(j);
    await _persist();
    _emit(urgent: true);
  }

  Future<void> _fail(TransferJob j, TransferFailure f) async {
    j.lastError = f.message.isEmpty ? f.code : f.message;
    j.lastErrorCode = f.code;
    j.lastRetryable = f.retryable;
    j.updatedAt = _now();
    if (!f.retryable || j.attempts >= maxAttempts) {
      j.status = TransferStatus.failed;
      j.nextAttemptAt = null;
    } else {
      // Geçici hata: üstel geri çekilme; ağ hatasında "Bağlantı bekleniyor".
      j.status = f.network ? TransferStatus.waitingNetwork : TransferStatus.queued;
      j.nextAttemptAt = _now().add(_backoff(j.attempts));
    }
    await _persist();
    _emit(urgent: true);
  }

  Future<void> _discard(TransferJob j) async {
    try {
      await _executors[j.kind]?.discard(j);
    } catch (_) {
      // Bilerek yutulur: sunucu kalıntısı temizliği en iyi çabadır (yetim ek gece süpürülür).
    }
  }

  Future<void> _deleteFiles(TransferJob j) async {
    if (j.direction != TransferDirection.upload) return;
    try {
      final dir = Directory('${(await store.filesDir()).path}${Platform.pathSeparator}${j.id}');
      if (await dir.exists()) await dir.delete(recursive: true);
      final f = File(j.localPath);
      if (await f.exists() && !j.localPath.contains(dir.path)) {
        // copySource=false ile verilen uygulama-dizini dosyası da iş bitince silinir
        await f.delete();
      }
    } catch (_) {
      // Bilerek yutulur: en iyi çaba.
    }
  }

  Future<void> _drop(TransferJob j, {required bool discardServer}) async {
    _cancelFlags.add(j.id);
    final hadServer = j.serverRef != null && j.publishedRef == null;
    if (!j.status.isTerminal) j.status = TransferStatus.canceled;
    if (discardServer && hadServer) await _discard(j);
    await _deleteFiles(j);
    _jobs.remove(j);
  }

  void _progress(TransferJob j, int done, int? total) {
    if (j.status != TransferStatus.active) return;
    j.doneBytes = total != null && total > 0 ? done.clamp(0, total) : done;
    if (total != null && total > 0) j.totalBytes = total;
    _emit();
  }

  void _processing(TransferJob j) {
    if (j.status != TransferStatus.active) return;
    j.status = TransferStatus.processing;
    j.updatedAt = _now();
    unawaited(_persist());
    _emit(urgent: true);
  }

  void _setServerRef(TransferJob j, String ref) {
    j.serverRef = ref;
    unawaited(_persist());
  }

  Future<void> _persist() {
    // Yazmalar sıralı; hatada kuyruk bozulmaz (bellekteki durum geçerli kalır).
    return _saving = _saving.then((_) => store.save(List.of(_jobs))).catchError((Object _) {});
  }

  // ---------------------------------------------------------------- yayın

  void _emit({bool urgent = false}) {
    if (urgent) {
      _emitTimer?.cancel();
      _emitTimer = null;
      _flush();
      return;
    }
    _emitTimer ??= Timer(emitInterval, () {
      _emitTimer = null;
      _flush();
    });
  }

  void _flush() {
    if (!_jobCtl.isClosed) _jobCtl.add(const []);
    final s = TransferSummary.of(_jobs.where((j) => j.ownerUserId == _owner));
    if (s == _lastSummary) return;
    _lastSummary = s;
    if (!_sumCtl.isClosed) _sumCtl.add(s);
    unawaited(platform.update(s, labels));
  }

  Future<void> dispose() async {
    _emitTimer?.cancel();
    _wakeTimer?.cancel();
    // close() dinleyici bitene dek bekleyebilir (async* akışları): beklenmez.
    unawaited(_jobCtl.close());
    unawaited(_sumCtl.close());
    await platform.stop();
  }

  static String _safeName(String path) {
    final base = path.split(RegExp(r'[\\/]')).last;
    final clean = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return clean.isEmpty ? 'file' : clean;
  }
}

class _Ctx implements TransferRunContext {
  _Ctx(this.q, this.j);
  final TransferQueue q;
  final TransferJob j;

  @override
  bool get canceled => j.status == TransferStatus.canceled || q._cancelFlags.contains(j.id);

  @override
  void progress(int done, [int? total]) => q._progress(j, done, total);

  @override
  void markProcessing() => q._processing(j);

  @override
  void setServerRef(String ref) => q._setServerRef(j, ref);
}
