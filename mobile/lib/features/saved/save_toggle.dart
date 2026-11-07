import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'saved_api.dart';

/// Etkinlik / kulüp detayında paylaş düğmesinin yanındaki kaydet (yer imi) düğmesi.
/// Açılışta `GET /bookmarks/{tür}/ids` ile durumu okur; dokununca iyimser günceller, hata olursa geri alır.
/// Düğmenin görünümü [builder] ile çağıran sayfaya bırakılır (kulüpte uygulama çubuğu simgesi, etkinlikte paylaş stili).
class SaveToggleButton extends StatefulWidget {
  const SaveToggleButton({
    super.key,
    required this.session,
    required this.kind,
    required this.id,
    required this.builder,
  });

  final Session session;

  /// event | community
  final String kind;
  final int id;
  final Widget Function(IconData icon, String tooltip, VoidCallback onTap) builder;

  @override
  State<SaveToggleButton> createState() => _SaveToggleButtonState();
}

class _SaveToggleButtonState extends State<SaveToggleButton> {
  late final SavedApi _api = SavedApi(widget.session);
  bool _saved = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _api.isSaved(widget.kind, widget.id);
      if (mounted && !_busy) setState(() => _saved = v);
    } catch (_) {
      // Durum okunamazsa kapalı görünür; dokununca yine denenir.
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final l = context.l10n;
    final was = _saved;
    setState(() {
      _saved = !was;
      _busy = true;
    });
    try {
      if (was) {
        await _api.unsave(widget.kind, widget.id);
      } else {
        await _api.save(widget.kind, widget.id);
      }
      Analytics.instance.action('bookmark', target: was ? 'remove' : 'add');
      if (mounted) BuToast.show(context, was ? l.svRemoved : l.svSavedToast, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saved = was);
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return widget.builder(_saved ? BuIcons.bookmarkFilled : BuIcons.bookmark, _saved ? l.svUnsave : l.svSave, _toggle);
  }
}

/// Sessize alma durumu için iyimser anahtar mantığı (kulüp / etkinlik detay sayfaları ortak kullanır).
class MuteController {
  MuteController(this.session, this.scope, this.id);

  final Session session;

  /// communities | events
  final String scope;
  final int id;

  /// null: henüz okunmadı / okunamadı.
  bool? muted;

  Future<void> load(VoidCallback changed) async {
    try {
      muted = await MuteApi(session).isMuted(scope, id);
      changed();
    } catch (_) {
      // Okunamazsa menü "sessize al" gösterir; seçimde yine denenir.
    }
  }

  /// İyimser: önce durumu çevirir, hata olursa geri alır ve hatayı bildirir.
  Future<void> toggle(BuildContext context, VoidCallback changed) async {
    final l = context.l10n;
    final was = muted ?? false;
    muted = !was;
    changed();
    try {
      final now = await MuteApi(session).setMuted(scope, id, !was);
      muted = now;
      changed();
      if (context.mounted) BuToast.show(context, now ? '${l.muteOnToast}. ${l.muteCriticalNote}' : l.muteOffToast, kind: BuToastKind.success);
    } catch (e) {
      muted = was;
      changed();
      if (context.mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }
}
