import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../core/nav.dart';
import '../../core/session.dart';
import 'share_models.dart';
import 'share_open.dart';

/// Gelen derin bağlantı (`https://bukampus.com.tr/s/{t}/{id}`, `bukampus://s/{t}/{id}`) yakalayıcısı.
///
/// Soğuk açılışta bağlantı uygulama açılırken gelir; oturum yoksa (giriş/kayıt/yasal onay/profil kurulumu) hedef
/// [pending]'de BEKLER ve ancak ana kabuk ([ShareLinkHost]) çizildiğinde açılır. Süre sınırı yoktur (uygulama
/// kapanana kadar bekler). Sıcak durumda bağlantı doğrudan açılır.
class ShareLinks {
  ShareLinks._();

  static final ShareLinks instance = ShareLinks._();

  /// Açılmayı bekleyen hedef (tek öğe; yeni bağlantı eskisinin yerini alır).
  final ValueNotifier<ShareTarget?> pending = ValueNotifier<ShareTarget?>(null);

  StreamSubscription<Uri>? _sub;
  ShareTarget? _lastTarget;
  DateTime? _lastAt;

  /// app_links ilk bağlantıyı da akıştan verir; aynı hedef 2 sn içinde yinelenirse (ilk bağlantı + akış) tek sayılır.
  static const Duration dedupeWindow = Duration(seconds: 2);

  /// Eklenti akışını başlatır (idempotent; hata sessizdir: bağlantı alınamazsa uygulama normal çalışır).
  Future<void> start({Stream<Uri>? stream}) async {
    if (_sub != null) return;
    try {
      final s = stream ?? AppLinks().uriLinkStream;
      _sub = s.listen(ingest, onError: (Object _) {}, cancelOnError: false);
    } catch (_) {
      // Eklenti yok/başlatılamadı (ör. test ortamı): derin bağlantı devre dışı kalır.
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Bir bağlantıyı işler: tanınan `/s/` bağlantısı hedef olur, diğerleri yok sayılır.
  @visibleForTesting
  void ingest(Uri? uri, {DateTime? now}) {
    final target = parseShareLink(uri);
    if (target == null) return;
    final t = now ?? DateTime.now();
    if (target == _lastTarget && _lastAt != null && t.difference(_lastAt!) < dedupeWindow) return;
    _lastTarget = target;
    _lastAt = t;
    // Aynı hedef art arda gelirse ValueNotifier bildirmez; önce temizleyip yeniden yazarak dinleyiciyi tetikle.
    pending.value = null;
    pending.value = target;
  }

  /// Bekleyen hedefi alır ve temizler.
  ShareTarget? take() {
    final t = pending.value;
    pending.value = null;
    return t;
  }

  @visibleForTesting
  void reset() {
    pending.value = null;
    _lastTarget = null;
    _lastAt = null;
  }
}

/// Ana kabuğun (tüm kapıların ardında) sarmalayıcısı: bekleyen derin bağlantıyı açar ve yenilerini dinler.
/// Yalnız oturum açıkken (kabuk çiziliyken) vardır; bu yüzden giriş akışı bitmeden hiçbir şey açılmaz.
class ShareLinkHost extends StatefulWidget {
  const ShareLinkHost({super.key, required this.session, required this.child, this.links});

  final Session session;
  final Widget child;

  /// Testlerde sahte yakalayıcı; varsayılan [ShareLinks.instance].
  final ShareLinks? links;

  @override
  State<ShareLinkHost> createState() => _ShareLinkHostState();
}

class _ShareLinkHostState extends State<ShareLinkHost> {
  ShareLinks get _links => widget.links ?? ShareLinks.instance;

  @override
  void initState() {
    super.initState();
    _links.pending.addListener(_check);
    // Soğuk açılış: kabuk ilk karesini çizdikten sonra bekleyen hedefi aç.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _links.pending.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || _links.pending.value == null) return;
    if (widget.session.state != SessionState.signedIn) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null || !nav.mounted) {
      // Gezinici henüz hazır değil: bir sonraki karede yeniden dene.
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      return;
    }
    final target = _links.take();
    if (target == null) return;
    // Hedef sayfa kapanana kadar beklenmez: ikinci bir bağlantı hemen açılabilir.
    unawaited(openShared(nav.context, widget.session, target));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
