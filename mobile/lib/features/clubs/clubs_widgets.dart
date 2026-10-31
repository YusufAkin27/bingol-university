import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'club_categories.dart';

String clubsInitials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final r = parts.first.runes.toList();
    return String.fromCharCodes(r.take(2)).toUpperCase();
  }
  return (String.fromCharCode(parts[0].runes.first) +
          String.fromCharCode(parts[1].runes.first))
      .toUpperCase();
}

/// Logo varsa görsel, yoksa baş harfli renkli karo.
class ClubsLogo extends StatelessWidget {
  const ClubsLogo(
      {super.key,
      required this.name,
      required this.id,
      this.url,
      this.size = 56,
      this.round = false});

  final String name;
  final int id;
  final String? url;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final tint = context.bu.tint(id);
    final radius = round ? size : 18 * size / 56;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint.bg, borderRadius: BorderRadius.circular(radius)),
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(clubsInitials(name), style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: tint.fg)),
      ),
    );
    if (fileUrl(url) == null) return ExcludeSemantics(child: tile);
    return ExcludeSemantics(child: BuImage(url, width: size, height: size, radius: radius));
  }
}

/// "Kulüplerim" yatay şeridi.
class ClubsMineStrip extends StatelessWidget {
  const ClubsMineStrip({super.key, required this.clubs, required this.onOpen});

  final List<Map<String, dynamic>> clubs;
  final void Function(Map<String, dynamic>) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return SizedBox(
      height: 64 + 6 + MediaQuery.textScalerOf(context).scale(12 * 1.2 * 2) + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        itemCount: clubs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final c = clubs[i];
          final name = (c['name'] ?? '').toString();
          return Semantics(
            button: true,
            label: name,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onOpen(c),
              child: SizedBox(
                width: 72,
                child: Column(
                  children: [
                    ClubsLogo(
                        name: name,
                        id: ((c['id'] as num?)?.toInt() ?? 0),
                        url: c['logoUrl'] as String?,
                        size: 64,
                        round: true),
                    const SizedBox(height: 6),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.ink, height: 1.2)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bölüm başlığı (17 / 800).
class ClubsSectionTitle extends StatelessWidget {
  const ClubsSectionTitle(this.text, {super.key, this.top = 22});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, top, 20, 10),
      child: Semantics(
        header: true,
        child: Text(text,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(color: context.bu.ink, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// "Tüm kulüpler" satırı: 56 px avatar, ad, açıklama, durum düğmesi.
class ClubsRowCard extends StatelessWidget {
  const ClubsRowCard(
      {super.key,
      required this.club,
      required this.busy,
      required this.onOpen,
      required this.onJoin});

  final Map<String, dynamic> club;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final name = (club['name'] as String?) ?? '';
    final category = ClubCategories.labelFor(club['category'] as String?);
    final desc = ((club['shortDescription'] ?? club['description']) as String?)
            ?.trim() ??
        '';
    final count = ((club['memberCount'] as num?) ?? 0).toInt();
    final sub = desc.isNotEmpty
        ? desc
        : [if (category.isNotEmpty) category, l.clubMgmtMemberCount('$count')]
            .join(' · ');
    final status = (club['myStatus'] as String?) ?? 'NONE';
    final id = ((club['id'] as num?)?.toInt() ?? 0);

    // Liste -> detay: logo uçarak büyür (BuHero; detaydaki aynı etiket). Köşe 18 -> daire yumuşak geçer.
    final avatar = BuHero(
      tag: BuHero.tagOf('club', id),
      radius: 18,
      child: ClubsLogo(name: name, id: id, url: club['logoUrl'] as String?, size: 56),
    );
    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)),
      ],
    );
    // Durum değişince (Katıl -> Üyesin / İstek gönderildi) düğme solarak yer değiştirir, küçük "pop" ile onaylanır.
    final button = BuPop(
      trigger: status,
      child: BuFadeThrough(
        duration: BuMotion.short,
        child: KeyedSubtree(key: ValueKey<String>(status), child: _button(context, status)),
      ),
    );
    final big = MediaQuery.textScalerOf(context).scale(10) > 12 ||
        (MediaQuery.sizeOf(context).width < 360 && status != 'NONE');

    return BuPressable(
      scale: .985,
      child: Container(
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: [
          BoxShadow(color: t.shadow.withValues(alpha: .12), blurRadius: 18, spreadRadius: -12, offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: t.sf.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: big
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titles,
                            const SizedBox(height: 10),
                            button,
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: titles),
                      const SizedBox(width: 8),
                      button,
                    ],
                  ),
          ),
        ),
      ),
    ));
  }

  Widget _button(BuildContext context, String status) {
    final l = context.l10n;
    switch (status) {
      case 'ACTIVE':
        return BuButton(
            label: l.clubMgmtYouAreMember,
            icon: LucideIcons.check,
            kind: BuButtonKind.soft,
            compact: true,
            onPressed: onOpen);
      case 'PENDING':
        return BuButton(
            label: l.clubMgmtRequestSent,
            kind: BuButtonKind.outline,
            compact: true,
            onPressed: onOpen);
      case 'BANNED':
        return BuButton(
            label: l.clubMgmtBanned, kind: BuButtonKind.outline, compact: true);
      default:
        return BuButton(
            label: l.clubMgmtJoin,
            compact: true,
            busy: busy,
            onPressed: busy ? null : onJoin);
    }
  }
}
