import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/system/gate_views.dart';
import 'analytics.dart';
import 'api.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Sayısal sürümleri karşılaştırır (1.2.3); eksik parça 0 sayılır. a<b -> -1.
int compareVersions(String a, String b) {
  List<int> p(String s) =>
      s.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final x = p(a), y = p(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c < 0 ? -1 : 1;
  }
  return 0;
}

/// Yalnızca https adresler mağaza bağlantısı olarak kabul edilir.
bool isSafeStoreUrl(String? u) {
  if (u == null) return false;
  final uri = Uri.tryParse(u);
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
}

enum GateKind { none, updateRequired, updateAvailable }

class GateDecision {
  const GateDecision({
    this.kind = GateKind.none,
    this.storeUrl,
    this.latest,
    this.maintenance = false,
    this.maintenanceMessage,
    this.banner,
  });
  final GateKind kind;
  final String? storeUrl;
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
  if (version != null) {
    latest = version['latestVersion'] as String?;
    store = version['storeUrl'] as String?;
    if (version['updateRequired'] == true) {
      kind = GateKind.updateRequired;
    } else if (version['updateAvailable'] == true ||
        (latest != null && compareVersions(current, latest) < 0)) {
      kind = GateKind.updateAvailable;
    }
  }
  if (!isSafeStoreUrl(store)) store = null;
  final m = info?['maintenance'];
  final maint = m is Map && m['enabled'] == true;
  String? nonEmpty(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return GateDecision(
    kind: kind,
    storeUrl: store,
    latest: latest,
    maintenance: maint,
    maintenanceMessage: maint ? nonEmpty(m['message']) : null,
    banner: nonEmpty(info?['banner']),
  );
}

/// "Güncelleme var" iletisi günde bir kez gösterilir.
bool shouldShowUpdateNotice(DateTime? lastShown, DateTime now) =>
    lastShown == null || now.difference(lastShown) >= const Duration(days: 1);

/// Ağ hatası alan katmanlar çağırabilir; kapı hemen yoklama yapar.
class ConnectivityHint {
  static final ValueNotifier<int> network = ValueNotifier<int>(0);
  static void reportNetworkError() => network.value++;
}

/// Açılış kapısı: sürüm/bakım/banner + çevrimdışı şeridi. MaterialApp.builder içinde kullanılır.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.api, required this.child});

  final ApiClient api;
  final Widget? child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  static const _minGap = Duration(minutes: 5);
  static const _noticeKey = 'update_notice_shown';

  GateDecision _d = const GateDecision();
  DateTime? _lastCheck;
  bool _noticeVisible = false;
  bool _offline = false;
  bool _checking = false;
  Timer? _probe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConnectivityHint.network.addListener(_ping);
    Analytics.instance.appOpen();
    _check();
    _startProbe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityHint.network.removeListener(_ping);
    _probe?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _startProbe();
      final last = _lastCheck;
      if (last == null || DateTime.now().difference(last) >= _minGap) _check();
      Analytics.instance.appOpen();
    } else if (s == AppLifecycleState.paused) {
      _probe?.cancel();
      Analytics.instance.flush();
    }
  }

  void _startProbe() {
    _probe?.cancel();
    _probe = Timer.periodic(const Duration(seconds: 20), (_) => _ping());
  }

  Future<void> _ping() async {
    try {
      await widget.api.get('/status');
      _setOffline(false);
    } on ApiError catch (e) {
      _setOffline(e.isNetwork);
    } catch (_) {}
  }

  void _setOffline(bool v) {
    if (mounted && v != _offline) setState(() => _offline = v);
  }

  Future<Map<String, dynamic>?> _getMap(String path) async {
    try {
      final r = await widget.api.get(path);
      return r is Map<String, dynamic> ? r : null;
    } catch (e) {
      if (e is ApiError && e.isNetwork) _setOffline(true);
      return null; // Ağ yoksa uygulama çalışmaya devam eder.
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final r = await Future.wait([
        _getMap('/app/version?platform=ios&version=${Uri.encodeQueryComponent(appVersion)}'),
        _getMap('/app/info'),
      ]);
      if (r[0] != null || r[1] != null) _setOffline(false);
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
      return UpdateRequiredScreen(storeUrl: _d.storeUrl);
    }
    final strips = <Widget>[
      if (_offline) const TopStrip(icon: Icons.cloud_off, text: 'Çevrimdışı', danger: true),
      if (_d.maintenance)
        TopStrip(icon: Icons.construction, text: _d.maintenanceMessage ?? 'Sistem bakımda.'),
      if (_d.banner != null) TopStrip(icon: Icons.campaign, text: _d.banner!),
    ];
    return Stack(
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
            left: 12,
            right: 12,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: UpdateNotice(
              latest: _d.latest,
              storeUrl: _d.storeUrl,
              onClose: () => setState(() => _noticeVisible = false),
            ),
          ),
      ],
    );
  }
}
