import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/system/gate_views.dart';
import '../widgets/bu_widgets.dart' show kNavInset;
import 'locale_controller.dart';
import 'analytics.dart';
import 'api.dart';
import 'device_identity.dart';
import 'icons/bu_icons.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '2.3.1');

/// Sayısal sürümleri karşılaştırır (1.2.3); eksik parça 0 sayılır. a<b -> -1.
int compareVersions(String a, String b) {
  // "2.2.0+22006" / "2.1.3-beta": yapı numarası ve ön sürüm eki karşılaştırmaya KATILMAZ (yoksa "0+22006" -> 22006 olurdu).
  List<int> p(String s) => s
      .split(RegExp(r'[+\-]'))
      .first
      .split('.')
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final x = p(a), y = p(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c < 0 ? -1 : 1;
  }
  return 0;
}

/// Yalnızca https adresler mağaza bağlantısı olarak kabul edilir.
bool isSafeStoreUrl(String? u) => isHttpsStoreUrl(u);

/// Sunucu güncelleme metni üst sınırı (sunucu 280'e sınırlar; savunma amaçlı).
const int kMaxUpdateMessage = 400;

/// Öne dönüşte sürüm/bakım yoklaması en sık bu aralıkla yapılır (ağ hatasında sessiz, açılışta ayrıca yapılır).
const Duration kResumeCheckGap = Duration(minutes: 15);

/// Öne dönüşte yeniden kontrol gerekir mi: hiç kontrol yoksa ya da son kontrolden [gap] geçtiyse.
bool shouldRecheckOnResume(DateTime? lastCheck, DateTime now, {Duration gap = kResumeCheckGap}) =>
    lastCheck == null || now.difference(lastCheck) >= gap;

enum GateKind { none, updateRequired, updateAvailable }

class GateDecision {
  const GateDecision({
    this.kind = GateKind.none,
    this.storeUrl,
    this.marketUrl,
    this.message,
    this.latest,
    this.maintenance = false,
    this.maintenanceMessage,
    this.banner,
  });
  final GateKind kind;
  final String? storeUrl;

  /// Doğrudan mağaza şeması (market:// / itms-apps://); önce denenir, olmazsa [storeUrl].
  final String? marketUrl;

  /// Yönetici güncelleme metni (istek dilinde); yoksa ekran varsayılan metni gösterir.
  final String? message;
  final String? latest;
  final bool maintenance;
  final String? maintenanceMessage;
  final String? banner;
}

/// Sunucu yanıtlarından karar üretir (saf; test edilir).
GateDecision decideGate(Map<String, dynamic>? version, Map<String, dynamic>? info,
    {String current = appVersion}) {
  var kind = GateKind.none;
  String? latest;
  String? store;
  String? market;
  String? message;
  if (version != null) {
    latest = version['latestVersion'] as String?;
    final su = version['storeUrl'];
    store = su is String ? su : null;
    final mu = version['marketUrl'];
    market = mu is String ? mu : null;
    final msg = version['message'];
    if (msg is String && msg.trim().isNotEmpty) {
      final m = msg.trim();
      message = m.length > kMaxUpdateMessage ? m.substring(0, kMaxUpdateMessage) : m;
    }
    if (version['updateRequired'] == true) {
      kind = GateKind.updateRequired;
    } else if (version['updateAvailable'] == true ||
        (latest != null && compareVersions(current, latest) < 0)) {
      kind = GateKind.updateAvailable;
    }
  }
  if (!isSafeStoreUrl(store)) store = null;
  if (!isSafeMarketUrl(market)) market = null;
  final m = info?['maintenance'];
  final maint = m is Map && m['enabled'] == true;
  String? nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return GateDecision(
    kind: kind,
    storeUrl: store,
    marketUrl: market,
    message: message,
    latest: latest,
    maintenance: maint,
    maintenanceMessage: maint ? nonEmpty(m['message']) : null,
    banner: nonEmpty(info?['banner']),
  );
}

/// "Güncelleme var" iletisi günde bir kez gösterilir.
bool shouldShowUpdateNotice(DateTime? lastShown, DateTime now) =>
    lastShown == null || now.difference(lastShown) >= const Duration(days: 1);

/// Açılış kapısı: sürüm/bakım/banner. MaterialApp.builder içinde kullanılır. Pasif "internet yok" şeridi YOK
/// (çevrimdışıyken kayıtlı veri sessizce gösterilir); bağlantı geri gelince sunucu durumu bir kez yeniden sorulur.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.api, required this.child});

  final ApiClient api;
  final Widget? child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  static const _noticeKey = 'update_notice_shown';

  GateDecision _d = const GateDecision();
  DateTime? _lastCheck;
  bool _noticeVisible = false;
  String? _dismissedBanner; // kapatılan duyuru metni (metin değişince yeniden görünür)
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.connectivity.reconnects.addListener(_onReconnect);
    Analytics.instance.appOpen();
    _check();
  }

  /// Çevrimdışından çıkıldı: bakım/sürüm bilgisi bir kez tazelenir (olay tabanlı, yoklama yok).
  void _onReconnect() {
    if (mounted) _check(force: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.api.connectivity.reconnects.removeListener(_onReconnect);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    Analytics.instance.onLifecycle(s); // oturum/ekran süresi; arka plana atılırken olaylar hemen gönderilir
    if (s == AppLifecycleState.resumed) {
      widget.api.outbox?.nudge(); // bekleyen mesajlar hemen denenir
      // Zorunlu güncelleme uygulama günlerce arka planda kalsa da devreye girsin: öne dönüşte (15 dk'da bir; kilit açıkken her dönüşte) tazelenir.
      if (_d.kind == GateKind.updateRequired || shouldRecheckOnResume(_lastCheck, DateTime.now())) _check(force: true);
      Analytics.instance.appOpen();
    }
  }

  Future<Map<String, dynamic>?> _getMap(String path, {bool force = false}) async {
    try {
      final r = await widget.api.get(path, force: force);
      return r is Map<String, dynamic> ? r : null;
    } catch (e) {
      return null; // Ağ yoksa uygulama çalışmaya devam eder (sessizce).
    }
  }

  /// [force]: bağlantı dönüşü / öne gelişte taze pencere yok sayılır (ilk açılışta ana sayfayla paylaşılan yanıt yeterli).
  Future<void> _check({bool force = false}) async {
    if (_checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final r = await Future.wait([
        _getMap('/app/version?platform=${DeviceIdentity.platform == 'ios' ? 'ios' : 'android'}&version=${Uri.encodeQueryComponent(appVersion)}', force: force),
        _getMap('/app/info', force: force),
      ]);
      // Ağ yokken zorunlu güncelleme kapısı kendiliğinden açılmasın: önceki karar korunur.
      // Kısmi kesintide de (yalnız sürüm ucu düşerse) zorunlu güncelleme kapısı kendiliğinden kalkmaz.
      if (r[0] == null && _d.kind == GateKind.updateRequired) return;
      final d = decideGate(r[0], r[1]);
      var showNotice = false;
      if (d.kind == GateKind.updateAvailable) {
        showNotice = await _noticeDue();
      }
      if (mounted) {
        setState(() {
          _d = d;
          _noticeVisible = showNotice;
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> _noticeDue() async {
    try {
      const st = FlutterSecureStorage();
      final raw = await st.read(key: _noticeKey);
      final ms = raw == null ? null : int.tryParse(raw);
      final last = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      final now = DateTime.now();
      if (!shouldShowUpdateNotice(last, now)) return false;
      await st.write(key: _noticeKey, value: now.millisecondsSinceEpoch.toString());
      return true;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child ?? const SizedBox.shrink();
    if (_d.kind == GateKind.updateRequired) {
      return UpdateRequiredScreen(
        storeUrl: _d.storeUrl,
        marketUrl: _d.marketUrl,
        message: _d.message,
        latest: _d.latest,
        current: appVersion,
        onRetry: () => _check(force: true),
      );
    }
    final l = context.l10n;
    final strips = <Widget>[
      if (_d.maintenance)
        GateNoticeStrip(
          icon: BuIcons.wrench,
          text: _d.maintenanceMessage ?? l.sistemuiMaintBand,
          kind: GateNoticeKind.maintenance,
        ),
      if (_d.banner != null && _d.banner != _dismissedBanner)
        GateNoticeStrip(
          icon: BuIcons.megaphone,
          text: _d.banner!,
          kind: GateNoticeKind.announcement,
          onClose: () => setState(() => _dismissedBanner = _d.banner),
        ),
    ];
    // Dokunuş = kullanım etkinliği (30 dk hareketsizlik sayacı); olay üretmez, dokunuşları engellemez.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => Analytics.instance.touch(),
      child: Stack(
        children: [
          Column(
            children: [
              if (strips.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: SafeArea(bottom: false, child: Column(children: strips)),
                ),
              Expanded(
                child: strips.isEmpty
                    ? child
                    : MediaQuery.removePadding(context: context, removeTop: true, child: child),
              ),
            ],
          ),
          if (_noticeVisible && _d.kind == GateKind.updateAvailable)
            Positioned(
              left: 16,
              right: 16,
              bottom: kNavInset - 8 + MediaQuery.of(context).padding.bottom,
              child: UpdateNotice(
                latest: _d.latest,
                storeUrl: _d.storeUrl,
                marketUrl: _d.marketUrl,
                onClose: () => setState(() => _noticeVisible = false),
              ),
            ),
        ],

      ),
    );
  }
}
