// Sohbet fotoğraflarını otomatik galeriye kaydetme (p22): gönderilen ve alınan fotoğraflar "BU Kampus" albümüne gider.
//
// Kurallar: VARSAYILAN KAPALI (kullanıcı Profil > Gizlilik ve veriler'den açıkça açar, rıza metniyle); yalnız birebir
// sohbet; tek gösterimlik ASLA; video değil; silinen/yönetici kaldırdığı mesaj değil; engellenen sohbet değil;
// ayar açıldıktan SONRA gelen/gönderilen (eski mesajlar yığılmaz); aynı ek iki kez kaydedilmez (ek kimliği bazlı).
// Kullanıcıya özeldir: çıkışta [PhotoAutoSave.reset] ayarı ve kaydedilen ek kimliklerini siler.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'chat_media.dart';

/// Kayıt sonucu: [denied] izin yok (çağıran tek seferlik bilgi verir), [failed] geçici hata (sonra yeniden denenir).
enum AutoSaveResult { saved, skipped, denied, failed }

/// Küçük anahtar-değer deposu (JSON dosyası); testte bellekte.
abstract class AutoSaveStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> data);

  /// Tüm kaydı siler (çıkış).
  Future<void> clear();
}

class MemoryAutoSaveStore implements AutoSaveStore {
  MemoryAutoSaveStore([Map<String, dynamic>? initial]) : data = {...?initial};
  Map<String, dynamic> data;

  @override
  Future<Map<String, dynamic>> load() async => {...data};

  @override
  Future<void> save(Map<String, dynamic> d) async => data = {...d};

  @override
  Future<void> clear() async => data = {};
}

class FileAutoSaveStore implements AutoSaveStore {
  FileAutoSaveStore({Future<Directory> Function()? dirProvider}) : _dirProvider = dirProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _dirProvider;
  File? _file;

  Future<File> _f() async {
    final f = _file;
    if (f != null) return f;
    final d = await _dirProvider();
    return _file = File('${d.path}${Platform.pathSeparator}photo_autosave.json');
  }

  @override
  Future<void> clear() async {
    try {
      final f = await _f();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> load() async {
    try {
      final f = await _f();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    try {
      await (await _f()).writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

typedef GalleryPut = Future<void> Function(Uint8List bytes, String name);
typedef PhotoFetch = Future<Uint8List?> Function(String url, Map<String, String> headers);

Future<void> _galPut(Uint8List bytes, String name) =>
    Gal.putImageBytes(bytes, album: PhotoAutoSave.album, name: name);

Future<Uint8List?> _httpFetch(String url, Map<String, String> headers) async {
  final r = await http.get(Uri.parse(chatMediaUrl(url)), headers: headers).timeout(const Duration(seconds: 30));
  return r.statusCode == 200 ? r.bodyBytes : null;
}

class PhotoAutoSave extends ChangeNotifier {
  PhotoAutoSave({AutoSaveStore? store, GalleryPut? put, PhotoFetch? fetch, DateTime Function()? now, bool? supported})
      : _store = store ?? FileAutoSaveStore(),
        _put = put ?? _galPut,
        _fetch = fetch ?? _httpFetch,
        _now = now ?? DateTime.now,
        _supported = supported ?? (Platform.isAndroid || Platform.isIOS);

  /// Uygulama geneli örnek (testler dizini değiştirmek için atayabilir).
  static PhotoAutoSave instance = PhotoAutoSave();

  /// Galeri albümü adı.
  static const album = 'BU Kampus';
  static const _maxSaved = 3000;

  final AutoSaveStore _store;
  final GalleryPut _put;
  final PhotoFetch _fetch;
  final DateTime Function() _now;
  final bool _supported;

  Map<String, dynamic>? _data;
  final Set<int> _busy = {};
  final Set<int> _failedThisSession = {};

  /// Kuşak: [reset] her çağrıda artar; sıfırlamadan önce başlamış işlemler sonucu yeni kullanıcının kaydına yazmaz.
  int _gen = 0;

  Future<Map<String, dynamic>> _load() async {
    final d = _data;
    if (d != null) return d;
    final gen = _gen;
    final loaded = await _store.load();
    if (gen != _gen) return _data ??= {}; // sıfırlama yarıştı: eski dosya içeriği geri gelmesin
    return _data ??= loaded;
  }

  /// Çıkış / hesap silme / oturum iptali: ayar, kaydedilen ek kimlikleri ve bildirim bayrakları (dosya + bellek) silinir.
  Future<void> reset() async {
    _gen++;
    _data = {};
    _busy.clear();
    _failedThisSession.clear();
    await _store.clear();
    notifyListeners();
  }

  /// Ayar açık mı. VARSAYILAN KAPALI: açıkça açılmadıysa (kayıt yok, eski sürümden kalan "anahtarsız" kayıt dahil)
  /// kapalı sayılır.
  Future<bool> enabled() async => (await _load())['enabled'] == true;

  /// Ayarı değiştirir. Açılış anı kaydedilir: yalnız bundan SONRAKİ fotoğraflar kaydedilir.
  Future<void> setEnabled(bool v) async {
    final d = await _load();
    d['enabled'] = v;
    if (v) {
      d['since'] = _now().millisecondsSinceEpoch;
      d['deniedNotified'] = false;
    }
    await _store.save(d);
    notifyListeners();
  }

  Future<int> _since() async {
    final d = await _load();
    var s = (d['since'] as num?)?.toInt();
    if (s == null) {
      // İlk kullanım (varsayılan açık): geçmiş mesajlar yığılmasın.
      s = _now().millisecondsSinceEpoch;
      d['since'] = s;
      await _store.save(d);
    }
    return s;
  }

  /// İzin reddi bilgisi daha önce verildi mi; vermediyse "verildi" diye işaretler ve true döner (tek seferlik).
  Future<bool> takeDeniedNotice() async {
    final d = await _load();
    if (d['deniedNotified'] == true) return false;
    d['deniedNotified'] = true;
    await _store.save(d);
    return true;
  }

  bool _isSaved(Map<String, dynamic> d, int id) => (d['saved'] as List?)?.contains(id) ?? false;

  Future<void> _mark(int id, int gen) async {
    if (gen != _gen) return; // oturum arada kapandı: yeni kullanıcının kaydı kirlenmesin
    final d = await _load();
    final list = ((d['saved'] as List?) ?? const []).cast<int>().toList()..add(id);
    if (list.length > _maxSaved) list.removeRange(0, list.length - _maxSaved);
    d['saved'] = list;
    await _store.save(d);
  }

  /// Ek kaydedilebilir bir FOTOĞRAF mı (mesaj durumu dahil). Saf işlev; test edilir.
  static bool isSavablePhoto(Map message, Map att) {
    if (message['deleted'] == true || message['removed'] == true) return false;
    if (att['removed'] == true || isViewOnceAttachment(att) || isVideoAttachment(att)) return false;
    if (att['url'] == null || (att['id'] as num?) == null) return false;
    final ct = '${att['contentType'] ?? 'image/jpeg'}';
    return ct.startsWith('image/');
  }

  /// Gönderen tarafı: yüklenen fotoğrafın yerel baytları (indirme yok). Tek gösterimlik çağrılmaz.
  ///
  /// [direct] false (grup / kulüp / etkinlik odası) ise kaydedilmez: otomatik kayıt yalnız birebir sohbetlerdedir.
  /// Çağıranlar bu bilgiyi vermezse varsayılan true'dur (imza geriye uyumlu).
  Future<AutoSaveResult> saveSent(int attId, Uint8List bytes, {bool direct = true}) async {
    if (!_supported || !direct || !await enabled()) return AutoSaveResult.skipped;
    final gen = _gen;
    if (_isSaved(await _load(), attId) || !_busy.add(attId)) return AutoSaveResult.skipped;
    try {
      await _put(bytes, 'bu_kampus_$attId');
      await _mark(attId, gen);
      return AutoSaveResult.saved;
    } catch (e) {
      return _classify(e);
    } finally {
      _busy.remove(attId);
    }
  }

  /// Alıcı tarafı: sunucudan gelen mesajlardaki yeni fotoğraflar indirilip kaydedilir.
  /// [isMine] kendi mesajlarını eler (onlar gönderimde kaydedilir); [blocked] engelli sohbeti tümden atlar.
  Future<List<AutoSaveResult>> considerReceived(
    List<Map<String, dynamic>> messages, {
    required Map<String, String> headers,
    required bool Function(Map<String, dynamic>) isMine,
    bool blocked = false,
    bool direct = true,
  }) async {
    final out = <AutoSaveResult>[];
    if (!_supported || blocked || !direct || !await enabled()) return out;
    final gen = _gen;
    final since = await _since();
    for (final m in messages) {
      if (isMine(m) || m['id'] == null) continue;
      final at = DateTime.tryParse('${m['createdAt'] ?? ''}')?.millisecondsSinceEpoch;
      if (at == null || at < since) continue;
      for (final a in (m['attachments'] as List? ?? const []).whereType<Map>()) {
        if (!isSavablePhoto(m, a)) continue;
        final id = (a['id'] as num).toInt();
        if (_isSaved(await _load(), id) || _failedThisSession.contains(id) || !_busy.add(id)) continue;
        try {
          final bytes = await _fetch('${a['url']}', headers);
          if (bytes == null || bytes.isEmpty) {
            _failedThisSession.add(id);
            out.add(AutoSaveResult.failed);
            continue;
          }
          await _put(bytes, 'bu_kampus_$id');
          await _mark(id, gen);
          out.add(AutoSaveResult.saved);
        } catch (e) {
          final r = _classify(e);
          if (r == AutoSaveResult.failed) _failedThisSession.add(id);
          out.add(r);
        } finally {
          _busy.remove(id);
        }
      }
    }
    return out;
  }

  AutoSaveResult _classify(Object e) {
    if (e is GalException && e.type == GalExceptionType.accessDenied) return AutoSaveResult.denied;
    debugPrint('Foto otomatik kayit basarisiz: ${e.runtimeType}');
    return AutoSaveResult.failed;
  }
}
