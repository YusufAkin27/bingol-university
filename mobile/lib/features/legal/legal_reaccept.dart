import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';

/// Yeniden onay bekleyen tek belge: tür (TERMS, PRIVACY, KVKK, COMMUNITY_RULES) + güncel sürüm.
class LegalItem {
  const LegalItem(this.type, this.version);

  final String type;
  final int version;

  Map<String, Object> toJson() => {'type': type, 'version': version};

  static LegalItem? tryParse(Object? o) {
    if (o is! Map) return null;
    final t = o['type'];
    final v = o['version'];
    if (t is! String || t.isEmpty || v is! num) return null;
    return LegalItem(t, v.toInt());
  }

  @override
  bool operator ==(Object other) => other is LegalItem && other.type == type && other.version == version;

  @override
  int get hashCode => Object.hash(type, version);
}

/// Yeniden onay durumu. `enforced` true ise sunucu yazma isteklerini reddeder (ekran atlanamaz).
class LegalReaccept {
  const LegalReaccept(this.items, {required this.enforced});

  final List<LegalItem> items;
  final bool enforced;

  /// "Daha sonra" seçimini hatırlamak için: aynı belge/sürüm kümesi aynı imzayı verir.
  String get signature => (items.map((e) => '${e.type}:${e.version}').toList()..sort()).join(',');
}

List<LegalItem> parseLegalItems(Object? raw) =>
    raw is List ? raw.map(LegalItem.tryParse).whereType<LegalItem>().toList() : <LegalItem>[];

/// Sözleşme yeniden onayı kapısının durumu.
///
/// - [check]: `GET /legal/acceptance-status`; bekleyen belge varsa [current] dolar (ekran açılır).
///   Ağ/geçici hata ya da beklenmeyen yanıtta kapı AÇILMAZ ve kullanıcı kilitlenmez.
/// - [onRequired]: herhangi bir yazma isteği 403 `LEGAL_REACCEPT_REQUIRED` alınca ([ApiClient.onLegalReaccept]);
///   ekran engelleyici (atlanamaz) olarak açılır.
/// - `enforced=false` iken ekran bir kez gösterilir ve "Daha sonra" ile geçilebilir; aynı belge/sürüm kümesi
///   için tekrar gösterilmez (yeni sürümde yeniden çıkar).
/// - Açık rıza (EXPLICIT_CONSENT) bu akışta DEĞİLDİR: ayrıdır, buradan verilmiş sayılmaz.
class LegalReacceptController extends ChangeNotifier {
  LegalReacceptController(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _laterKey = 'legal_later';

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  /// Null değilse onay ekranı gösterilir.
  LegalReaccept? current;
  bool _checking = false;
  int? _userId;

  Future<void> check({int? userId}) async {
    if (_checking) return;
    _checking = true;
    if (userId != null) _userId = userId;
    try {
      Object? res;
      try {
        res = await _api.get('/legal/acceptance-status');
      } catch (_) {
        return; // geçici hata / çevrimdışı: kapıyı açma, durumu koru
      }
      if (res is! Map) return;
      final items = parseLegalItems(res['requiresAcceptance']);
      final enforced = res['enforced'] == true;
      if (items.isEmpty) {
        _set(null);
        return;
      }
      final next = LegalReaccept(items, enforced: enforced);
      if (!enforced && await _deferred(next)) {
        _set(null);
        return;
      }
      _set(next);
    } finally {
      _checking = false;
    }
  }

  /// 403 LEGAL_REACCEPT_REQUIRED: yanıttaki liste kullanılır; boşsa durum sunucudan yeniden sorulur.
  void onRequired(Object? requiresAcceptance) {
    final items = parseLegalItems(requiresAcceptance);
    if (items.isEmpty) {
      // Liste gelmediyse sunucudan al; ekran yine de engelleyici olsun diye geçici durum konur.
      final keep = current?.items ?? const <LegalItem>[];
      if (keep.isNotEmpty) _set(LegalReaccept(keep, enforced: true));
      check();
      return;
    }
    _set(LegalReaccept(items, enforced: true));
  }

  /// Gösterilen tüm belgeleri kabul eder (`POST /legal/accept`). Başarıda ekran kapanır.
  /// 409 VERSION_OUTDATED: belge listesi yenilenir ve hata çağırana iletilir (kullanıcı yeni sürümü görsün).
  Future<void> accept() async {
    final c = current;
    if (c == null) return;
    try {
      await _api.post('/legal/accept', {'items': [for (final i in c.items) i.toJson()]});
    } on ApiError catch (e) {
      if (e.code == 'VERSION_OUTDATED') await check();
      rethrow;
    }
    await _clearDeferred();
    _set(null);
  }

  /// "Daha sonra": yalnız `enforced=false` iken; aynı sürüm kümesi için bir daha gösterilmez.
  Future<void> defer() async {
    final c = current;
    if (c == null || c.enforced) return;
    try {
      await _storage.write(key: _laterKey, value: '${_userId ?? 0}|${c.signature}');
    } catch (_) {}
    _set(null);
  }

  /// Çıkışta: bellek durumu temizlenir (kalıcı "daha sonra" kaydı kullanıcıya bağlı olduğundan kalır).
  void reset() {
    _userId = null;
    _set(null);
  }

  Future<bool> _deferred(LegalReaccept c) async {
    try {
      return await _storage.read(key: _laterKey) == '${_userId ?? 0}|${c.signature}';
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearDeferred() async {
    try {
      await _storage.delete(key: _laterKey);
    } catch (_) {}
  }

  void _set(LegalReaccept? v) {
    final same = (v == null && current == null) ||
        (v != null && current != null && v.enforced == current!.enforced && v.signature == current!.signature);
    if (same) return;
    current = v;
    notifyListeners();
  }
}
