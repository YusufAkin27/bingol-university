import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../app_hooks.dart';
import '../connectivity/connectivity_service.dart';
import '../session.dart';
import 'transfer_executor.dart';
import 'transfer_job.dart';
import 'transfer_platform.dart';
import 'transfer_queue.dart';
import 'transfer_store.dart';

/// Uygulama genelinde tek [TransferQueue] sahibi. Oturum kancalarına bağlanır:
///  - giriş: kuyruk o hesap için açılır, yarım işler kurtarılır;
///  - çıkış / hesap değişimi / hesap silme: ilgili hesabın işleri durdurulur, yerel dosyalar silinir;
///  - bağlantı geri gelince bekleyen işlerin geri çekilmesi atlanır.
/// Özellikler (G2 gönderi, G4 sohbet) çalıştırıcılarını [addExecutor] ile KAYDEDER (oturumdan önce de çağrılabilir).
class TransferHub {
  TransferHub._();
  static final TransferHub instance = TransferHub._();

  TransferQueue? _queue;
  final Map<TransferKind, TransferExecutor Function(Session)> _factories = {};
  TransferLabels labels = const TransferLabels();
  bool _wired = false;

  /// Oturum açıkken dolu; çıkışta da kalır (boş iş listesiyle).
  TransferQueue? get queue => _queue;

  void addExecutor(TransferKind kind, TransferExecutor Function(Session) factory) {
    _factories[kind] = factory;
    final q = _queue;
    final s = _session;
    if (q != null && s != null) q.registerExecutor(kind, factory(s));
  }

  Session? _session;

  void attach(Session session, ConnectivityService connectivity, {AppLifecycleHooks? hooks}) {
    if (_wired) return;
    _wired = true;
    _session = session;
    final h = hooks ?? AppLifecycleHooks.instance;
    h.onSignedIn.add((s) => unawaited(_signedIn(s)));
    h.onSignedOut.add((_) => unawaited(_queue?.signOut()));
    connectivity.reconnects.addListener(() => _queue?.nudge());
  }

  Future<void> _signedIn(Session s) async {
    final uid = s.userId;
    if (uid == null) return;
    var q = _queue;
    if (q == null) {
      final base = await getApplicationSupportDirectory();
      q = TransferQueue(
        store: FileTransferStore(Directory('${base.path}${Platform.pathSeparator}transfers')),
        platform: defaultTransferPlatform(),
        labels: labels,
      );
      _queue = q;
      _factories.forEach((k, f) => q!.registerExecutor(k, f(s)));
    }
    await q.start(uid);
  }
}
