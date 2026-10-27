import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../core/typography.dart';

/// Tasarımdaki aç/kapat anahtarı (46x28, beyaz topuz).
class PrefSwitch extends StatelessWidget {
  const PrefSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(color: value ? t.pr : t.sf2, borderRadius: BorderRadius.circular(14)),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 3, offset: const Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// Anahtar satırı (etiket + sağda anahtar).
class PrefSwitchRow extends StatelessWidget {
  const PrefSwitchRow({super.key, required this.label, required this.value, this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: t.ink))),
          PrefSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

const _prefRows = [
  ('news', 'Haberler'),
  ('announcements', 'Duyurular'),
  ('events', 'Etkinlikler'),
  ('communities', 'Topluluklar'),
  ('messages', 'Mesajlar'),
];

/// Bildirim anahtarları grubu: yüklenir, her değişiklik anında kaydedilir, hatada geri alınır.
/// Ayarlar sayfasında ve tek başına sayfada kullanılır.
class NotificationPrefsGroup extends StatefulWidget {
  const NotificationPrefsGroup({super.key, required this.session});

  final Session session;

  @override
  State<NotificationPrefsGroup> createState() => _NotificationPrefsGroupState();
}

class _NotificationPrefsGroupState extends State<NotificationPrefsGroup> {
  Map<String, dynamic>? _prefs;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.session.api.get('/notifications/preferences') as Map<String, dynamic>;
      if (mounted) setState(() => _prefs = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _set(String key, bool value) async {
    final old = Map<String, dynamic>.from(_prefs!);
    setState(() => _prefs![key] = value);
    try {
      final r = await widget.session.api.put('/notifications/preferences', {
        for (final row in _prefRows) row.$1: _prefs![row.$1] == true,
      });
      if (mounted && r is Map<String, dynamic>) setState(() => _prefs = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = old);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    if (_error != null) {
      return BuCard(
        onTap: _load,
        child: Row(children: [
          Icon(LucideIcons.refreshCw, size: 16, color: t.pr),
          const SizedBox(width: 10),
          Expanded(child: Text('${errorText(_error!)} Yeniden denemek için dokunun.', style: BuType.caption.copyWith(color: t.mut))),
        ]),
      );
    }
    if (_prefs == null) {
      return const BuCard(child: SizedBox(height: 52, child: LoadingView()));
    }
    return BuGroup(children: [
      for (final r in _prefRows)
        PrefSwitchRow(label: r.$2, value: _prefs![r.$1] == true, onChanged: (v) => _set(r.$1, v)),
    ]);
  }
}

/// Bildirim türü bazında aç/kapat (tek başına sayfa).
class NotificationPrefsPage extends StatelessWidget {
  const NotificationPrefsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(
        children: [
          BuHeader(title: 'Bildirimler', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [NotificationPrefsGroup(session: session)],
            ),
          ),
        ],
      ),
    );
  }
}
