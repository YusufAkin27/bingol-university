import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/secure_store.dart';
import '../../widgets/bu.dart';

/// Geri bildirim türü simgeleri (tür kartları).
const Map<String, IconData> supportFeedbackIcons = {
  'BUG': BuIcons.triangleAlert,
  'SUGGESTION': BuIcons.lightbulb,
  'COMPLAINT': BuIcons.flag,
  'PRAISE': BuIcons.heart,
};

/// Sunucuda aynı anda açık tutulabilen talep sayısı (`app.support.max-open-tickets`); liste yanıtında `maxOpen` gelmezse.
const kSupportDefaultMaxOpen = 5;

/// İki sütunlu seçim kartları (talep kategorisi, geri bildirim türü): simge karosu + ad; seçili kart marka zeminli,
/// 1.5 dp `pr` çerçeveli ve onay işaretli. Dar ekranda da iki sütun kalır (etiket 2 satıra iner).
class SupportChoiceGrid extends StatelessWidget {
  const SupportChoiceGrid({super.key, required this.options, required this.value, required this.onChanged, required this.icons});

  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Map<String, IconData> icons;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - gap) / 2;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final e in options.entries)
          SizedBox(
            width: w,
            child: Semantics(
              button: true,
              selected: e.key == value,
              label: e.value,
              excludeSemantics: true,
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                curve: BuMotion.standard,
                decoration: BoxDecoration(
                  color: e.key == value ? t.soft : t.sf,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: e.key == value ? t.pr : t.bdStrong, width: e.key == value ? 1.5 : 1),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: ValueKey('supChoice${e.key}'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (e.key != value) buHaptic(BuHaptic.selection);
                      onChanged(e.key);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: e.key == value ? t.sf : t.sf2, borderRadius: BorderRadius.circular(11)),
                            child: Icon(icons[e.key] ?? BuIcons.ellipsis, size: 18, color: e.key == value ? t.pr : t.ink),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: tx.labelLarge!.copyWith(color: e.key == value ? t.onSoft : t.ink, fontWeight: FontWeight.w700, height: 1.2)),
                          ),
                          if (e.key == value) Icon(BuIcons.circleCheckFilled, size: 18, color: t.pr),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

/// "Açık talep 2 / 5" göstergesi: sol etiket + sağ sayaç, altında [max] parçalı çubuk. Sınırda uyarı tonu.
class SupportOpenMeter extends StatelessWidget {
  const SupportOpenMeter({super.key, required this.open, required this.max});

  final int open;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final full = open >= max;
    final fill = full ? t.danger : t.pr;
    return Semantics(
      container: true,
      label: l.supOpenMeterSemantics('$open', '$max'),
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(l.supOpenMeterLabel, style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w600))),
          Text('$open / $max', textDirection: TextDirection.ltr, style: tx.labelLarge!.copyWith(color: full ? t.danger : t.ink, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < max; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.medium),
                height: 6,
                decoration: BoxDecoration(color: i < open ? fill : t.sf3, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Açık talep sınırına ulaşılınca "Yeni talep" düğmesinin yerine geçen açıklama (sunucu hatası beklenmeden).
class SupportLimitNote extends StatelessWidget {
  const SupportLimitNote({super.key, required this.max});

  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 16, 14),
        decoration: BoxDecoration(color: t.warnSoft, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.warn.withValues(alpha: .16), borderRadius: BorderRadius.circular(13)),
            child: ExcludeSemantics(child: Icon(BuIcons.lock, size: 20, color: t.onWarnSoft)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.supLimitTitle, style: tx.titleSmall!.copyWith(color: t.onWarnSoft, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 2),
              Text(l.supLimitBody('$max'), style: tx.bodyMedium!.copyWith(color: t.onWarnSoft, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Hangi talebin son yanıtını görüp görmediğimiz (cihazda): `{talepNo: görülen updatedAt}`. Sunucu "okundu" alanı
/// vermiyorsa liste, durumu YANITLANDI olup henüz açılmamış talepleri "Yeni yanıt" diye vurgular.
class SupportSeenStore {
  SupportSeenStore._();

  static const _key = 'support_seen_v1';
  static const _keep = 100;

  /// Testlerde belleğe yönlendirilebilir.
  @visibleForTesting
  static Map<int, String>? memory;

  static Future<Map<int, String>> load() async {
    final m = memory;
    if (m != null) return Map.of(m);
    try {
      final raw = await kDeviceSecureStorage.read(key: _key);
      if (raw == null || raw.isEmpty) return {};
      final j = jsonDecode(raw);
      if (j is! Map) return {};
      return {
        for (final e in j.entries)
          if (int.tryParse('${e.key}') != null) int.parse('${e.key}'): '${e.value}',
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> mark(int id, String? updatedAt) async {
    if (updatedAt == null || updatedAt.isEmpty) return;
    final cur = await load();
    if (cur[id] == updatedAt) return;
    cur.remove(id);
    cur[id] = updatedAt;
    while (cur.length > _keep) {
      cur.remove(cur.keys.first);
    }
    if (memory != null) {
      memory = cur;
      return;
    }
    try {
      await kDeviceSecureStorage.write(key: _key, value: jsonEncode({for (final e in cur.entries) '${e.key}': e.value}));
    } catch (_) {}
  }
}

/// Talep "yeni yanıt" mı: sunucu `unread` verirse o; yoksa YANITLANDI + görülmemiş + son 14 gün içinde.
bool supportTicketUnread(Map<String, dynamic> ticket, Map<int, String> seen, {DateTime? now}) {
  final flag = ticket['unread'] ?? ticket['hasUnreadReply'];
  if (flag is bool) return flag && ticket['status'] != 'CLOSED';
  if (ticket['status'] != 'ANSWERED') return false;
  final id = (ticket['id'] as num?)?.toInt();
  final at = '${ticket['updatedAt'] ?? ticket['createdAt'] ?? ''}';
  if (id == null || at.isEmpty || seen[id] == at) return false;
  final d = DateTime.tryParse(at);
  if (d == null) return false;
  return (now ?? DateTime.now()).difference(d.toLocal()).inDays < 14;
}
