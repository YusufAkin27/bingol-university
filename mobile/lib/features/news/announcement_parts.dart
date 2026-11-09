import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../academic/academic_models.dart' show istanbulWall;
import 'icerik_parts.dart';
import 'news_tile.dart';

/// Duyuru görünümü parçaları (liste kartı, tarih grupları, ek satırı). Premium monochrome:
/// vurgu rengi yok, kalın yazı yok, ayrım ince kenarlık + yüzey tonuyla.

/// Duyuru listesindeki tarih grubu.
enum AnnouncementGroup { today, week, older }

/// Grup başlığı (dil koduna göre; ortak l10n dosyalarına dokunmadan yerel tutulur).
String announcementGroupLabel(String lang, AnnouncementGroup g) {
  const tr = {AnnouncementGroup.today: 'Bugün', AnnouncementGroup.week: 'Bu hafta', AnnouncementGroup.older: 'Daha eski'};
  const en = {AnnouncementGroup.today: 'Today', AnnouncementGroup.week: 'This week', AnnouncementGroup.older: 'Earlier'};
  const ar = {AnnouncementGroup.today: 'اليوم', AnnouncementGroup.week: 'هذا الأسبوع', AnnouncementGroup.older: 'أقدم'};
  return switch (lang) { 'en' => en, 'ar' => ar, _ => tr }[g]!;
}

/// Ek satırının ikinci satırı (dosya türü yoksa "Ek").
String announcementOpenHint(String lang) => switch (lang) { 'en' => 'Opens in browser', 'ar' => 'يُفتح في المتصفح', _ => 'Tarayıcıda açılır' };

/// Yayın tarihini kampüs saatinde (yyyy-MM-dd ya da zaman damgası) takvim gününe çevirir; ayrıştırılamazsa null.
DateTime? announcementDay(String? iso) {
  final inst = iso == null ? null : DateTime.tryParse(iso);
  if (inst == null) return null;
  final d = inst.isUtc ? istanbulWall(inst) : inst;
  return DateTime(d.year, d.month, d.day);
}

/// Tarihe göre grup: bugün, son 7 gün, daha eski (tarihsiz = daha eski).
AnnouncementGroup announcementGroupOf(String? iso, DateTime now) {
  final d = announcementDay(iso);
  if (d == null) return AnnouncementGroup.older;
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff <= 0) return AnnouncementGroup.today;
  if (diff < 7) return AnnouncementGroup.week;
  return AnnouncementGroup.older;
}

/// Düz satır listesi: başlık ([AnnouncementGroup]) ve kayıtlar ([Map]) iç içe; sıra korunur,
/// yalnız grup değişince başlık eklenir (sunucu sırası tarihe göre azalandır).
List<Object> groupAnnouncements(List<Map<String, dynamic>> items, DateTime now) {
  final out = <Object>[];
  AnnouncementGroup? last;
  for (final it in items) {
    final g = announcementGroupOf(it['publishedDate'] as String?, now);
    if (g != last) {
      out.add(g);
      last = g;
    }
    out.add(it);
  }
  return out;
}

/// Grup başlığı: soluk etiket + ince çizgi.
class AnnouncementGroupHeader extends StatelessWidget {
  const AnnouncementGroupHeader({super.key, required this.group, this.first = false});

  final AnnouncementGroup group;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final lang = Localizations.localeOf(context).languageCode;
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 10),
        child: Row(children: [
          Text(announcementGroupLabel(lang, group), style: BuType.caption.copyWith(fontSize: 13, height: 1.3, color: t.mut)),
          const SizedBox(width: 12),
          Expanded(child: Divider(height: 1, thickness: 1, color: t.bd)),
        ]),
      ),
    );
  }
}

/// Sol tarih bloğu: gün sayısı + ay adı (56 dp kare, sığmazsa küçülür; metin ölçeğinde taşmaz).
class AnnouncementDateBlock extends StatelessWidget {
  const AnnouncementDateBlock({super.key, required this.day, required this.month});

  final int day;
  final String month;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.bd)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$day', style: tx.titleLarge!.copyWith(fontSize: 22, fontWeight: FontWeight.w400, height: 1.1, color: t.ink)),
            Text(month, maxLines: 1, style: BuType.caption.copyWith(fontSize: 12, height: 1.2, color: t.mut)),
          ]),
        ),
      ),
    );
  }
}

/// Duyuru kartı: [tarih bloğu] başlık (3 satır) + kaynak/birim satırı; isteğe bağlı kaydet düğmesi, yoksa ok.
class AnnouncementTile extends StatelessWidget {
  const AnnouncementTile({
    super.key,
    required this.item,
    required this.onTap,
    this.saved = false,
    this.onToggleSave,
    this.showSource = true,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final bool saved;
  final VoidCallback? onToggleSave;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final day = announcementDay(item['publishedDate'] as String?);
    final unit = '${item['unitName'] ?? ''}'.trim();
    final host = showSource ? newsSourceHost(item) : '';
    final meta = [if (unit.isNotEmpty) unit else if (host.isNotEmpty) host, if (day != null) newsLocalDate(context, item['publishedDate'] as String?)].join(' · ');
    final title = (item['title'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: IcerikCard(
          onTap: onTap,
          shadow: false,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 6, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (day != null)
              AnnouncementDateBlock(day: day.day, month: trUpper(newsMonthName(context, day.month)).characters.take(3).toString())
            else
              Container(
                width: 56,
                height: 60,
                decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.bd)),
                child: Icon(BuIcons.megaphone, size: 22, color: t.mut),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: tx.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4, color: t.ink)),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodySmall!.copyWith(fontSize: 13, height: 1.35, color: t.mut)),
                  ],
                ]),
              ),
            ),
            if (onToggleSave != null)
              newsSaveIcon(saved: saved, onTap: onToggleSave!)
            else
              SizedBox(width: 24, height: 60, child: Icon(buDirIcon(context, BuIcons.chevronRight), size: 20, color: t.mut)),
          ]),
        ),
      ),
    );
  }
}

/// Ek satırı: [dosya simgesi] ad (en çok 2 satır) + ipucu, sonda dış bağlantı oku; 56 dp yüksek.
class AnnouncementAttachmentRow extends StatelessWidget {
  const AnnouncementAttachmentRow({super.key, required this.name, required this.kind, required this.onTap});

  final String name;
  final String? kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final k = (kind ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IcerikCard(
        onTap: onTap,
        shadow: false,
        radius: 16,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.bd)),
              child: Icon(BuIcons.fileText, size: 20, color: t.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.35, color: t.ink)),
                Text([if (k.isNotEmpty) k.toUpperCase(), announcementOpenHint(lang)].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(fontSize: 13, height: 1.35, color: t.mut)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(BuIcons.arrowUpRight, size: 18, color: t.mut),
          ]),
        ),
      ),
    );
  }
}
