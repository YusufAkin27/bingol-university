import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../academic/reminder_settings_page.dart';
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
    // Kapalı: çerçeveli iz + koyu topuz (iz/topuz kontrastı >= 3:1); açık: kırmızı iz + onPr topuz.
    return Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 52,
          height: 44, // dokunma alanı
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: value ? t.pr : t.sf2,
                borderRadius: BorderRadius.circular(14),
                border: value ? null : Border.all(color: t.mut, width: 1.5),
              ),
              child: Container(
                width: value ? 22 : 18,
                height: value ? 22 : 18,
                margin: EdgeInsets.all(value ? 0 : 2),
                decoration: BoxDecoration(color: value ? t.onPr : t.mut, shape: BoxShape.circle),
              ),
            ),
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
    // Tüm satır dokunulabilir; ekran okuyucu "etiket, anahtar, açık/kapalı" okur.
    return MergeSemantics(
      child: Semantics(
        child: InkWell(
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 10, 4),
            child: Row(
              children: [
                Expanded(child: Text(label, style: BuType.bodyStrong.copyWith(color: t.ink))),
                const SizedBox(width: 8),
                PrefSwitch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sunucunun ana bayrakları (her zaman gösterilir).
const _prefRows = [
  ('news', 'Haberler'),
  ('announcements', 'Duyurular'),
  ('events', 'Etkinlikler'),
  ('communities', 'Topluluklar'),
  ('messages', 'Mesajlar'),
];

/// Sunucu yanıtında anahtar varsa gösterilen ek ana bayraklar (backend eklenene kadar gizli kalır).
const _optionalRows = [
  ('polls', 'Anketler'),
  ('academicAnnouncements', 'Akademik duyurular'),
  ('stories', 'Hikâyeler'),
];

/// Alt türler (`subtypes`): yalnızca sunucu yanıtında bulunanlar gösterilir; bilinmeyen anahtar gönderilmez (400).
const _subtypeRows = [
  ('POST_MENTION', 'Etiketlenmeler'),
  ('USER_FOLLOW', 'Yeni takipçiler'),
  ('POST_LIKE', 'Gönderi beğenileri'),
  ('POST_COMMENT', 'Gönderi yorumları'),
  ('COMMENT_REPLY', 'Yorum yanıtları'),
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

  Map<String, dynamic> get _subs => (_prefs?['subtypes'] is Map) ? (_prefs!['subtypes'] as Map).cast<String, dynamic>() : {};

  /// Yalnız değişen alan gönderilir (kısmi güncelleme); hatada eski değere dönülür.
  Future<void> _save(Map<String, dynamic> body, void Function() apply) async {
    final old = jsonDecode(jsonEncode(_prefs)) as Map<String, dynamic>;
    setState(apply);
    try {
      final r = await widget.session.api.put('/notifications/preferences', body);
      if (mounted && r is Map<String, dynamic>) setState(() => _prefs = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _prefs = old);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  Future<void> _set(String key, bool value) => _save({key: value}, () => _prefs![key] = value);

  Future<void> _setSub(String key, bool value) => _save({
        'subtypes': {key: value}
      }, () {
        final m = Map<String, dynamic>.from(_subs)..[key] = value;
        _prefs!['subtypes'] = m;
      });

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
    final subs = _subs;
    final subRows = [for (final r in _subtypeRows) if (subs.containsKey(r.$1)) r];
    final optional = [for (final r in _optionalRows) if (_prefs!.containsKey(r.$1)) r];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuGroup(children: [
          for (final r in _prefRows)
            PrefSwitchRow(label: r.$2, value: _prefs![r.$1] == true, onChanged: (v) => _set(r.$1, v)),
          for (final r in optional)
            PrefSwitchRow(label: r.$2, value: _prefs![r.$1] == true, onChanged: (v) => _set(r.$1, v)),
        ]),
        if (subRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          const BuSectionTitle('Sosyal'),
          const SizedBox(height: 8),
          BuGroup(children: [
            for (final r in subRows)
              PrefSwitchRow(
                // Üst bayrak (topluluklar) kapalıysa alt tür etkisizdir.
                label: r.$2,
                value: subs[r.$1] == true && _prefs!['communities'] == true,
                onChanged: _prefs!['communities'] == true ? (v) => _setSub(r.$1, v) : null,
              ),
          ]),
        ],
        const SizedBox(height: 16),
        const BuSectionTitle('Bu cihazda'),
        const SizedBox(height: 8),
        BuGroup(children: [
          InkWell(
            onTap: () => Navigator.push<void>(
                context, MaterialPageRoute<void>(builder: (_) => ReminderSettingsPage(session: widget.session))),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
              child: Row(children: [
                Expanded(child: Text('Ders ve sınav hatırlatmaları', style: BuType.bodyStrong.copyWith(color: t.ink))),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
              ]),
            ),
          ),
        ]),
      ],
    );
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
