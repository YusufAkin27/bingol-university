import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'club_actions.dart';
import 'club_categories.dart';

// Kulüpler: Stitch v3 (docs/design/BIREBIR_KULUP.md). Kartsız satır + ince ayraç, 48 dp daire logo, 36 dp çerçeveli
// "Katıl", metin sekmeleri (2 dp marka alt çizgisi). Renk yalnız belirteçlerden; gölge/gradyan yok.

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

/// Logo varsa görsel, yoksa `sf2` zeminli iki harf (soluk, 600). Varsayılan 48 dp daire.
class ClubsLogo extends StatelessWidget {
  const ClubsLogo(
      {super.key,
      required this.name,
      required this.id,
      this.url,
      this.size = 48,
      this.round = true});

  final String name;
  final int id;
  final String? url;
  final double size;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final radius = round ? size : 18 * size / 56;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(radius)),
      padding: const EdgeInsets.all(4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(clubsInitials(name), style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
      ),
    );
    if (fileUrl(url) == null) return ExcludeSemantics(child: tile);
    return ExcludeSemantics(child: BuImage(url, width: size, height: size, radius: radius));
  }
}

/// Metin sekmeleri: seçili = marka metni + 2 dp marka alt çizgisi; altta tam genişlik ince ayraç. Dolu hap yok.
/// Dar ekranda/büyük yazıda yatay kayar. Yükseklik 44 dp; her sekme en az 48 dp geniş dokunma alanı.
class ClubTextTabs extends StatelessWidget {
  const ClubTextTabs({super.key, required this.labels, required this.index, required this.onChanged, this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 20)});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry padding;

  static const double height = 42;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Stack(
      children: [
        PositionedDirectional(start: 0, end: 0, bottom: 0, child: Container(height: 1, color: t.bd)),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: padding,
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 24),
            itemBuilder: (_, i) {
              final on = i == index;
              return Semantics(
                button: true,
                selected: on,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!on) buHaptic(BuHaptic.selection);
                    onChanged(i);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 48),
                    child: Stack(
                      children: [
                        Center(
                          widthFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: AnimatedDefaultTextStyle(
                              duration: BuMotion.of(context, BuMotion.short),
                              curve: BuMotion.standard,
                              style: tx.bodyLarge!.copyWith(fontWeight: FontWeight.w600, color: on ? t.pr : t.mut),
                              child: Text(labels[i], maxLines: 1, softWrap: false),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: BuMotion.of(context, BuMotion.short),
                            curve: BuMotion.standard,
                            height: 2,
                            color: on ? t.pr : t.pr.withValues(alpha: 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bölüm etiketi (YÖNETTİKLERİM): 12-13 sp muted/600, harf aralıklı; üstte 24 dp boşluk.
class ClubsSectionTitle extends StatelessWidget {
  const ClubsSectionTitle(this.text, {super.key, this.top = 24});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20, top, 20, 10),
      child: Semantics(
        header: true,
        child: Text(ar ? text : trUpper(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.mut, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: ar ? 0 : .6)),
      ),
    );
  }
}

/// Kulüp satırı (kartsız): sol 48 dp logo, orta ad + "Kategori · N üye", sağ durum. Altta tam genişlik `bd` ayraç.
/// [mine] true ("Kulüplerim"): sağ metin rol / "Yanıt bekleniyor"; false (Keşfet): Katıl / Üyesin / İstek gönderildi.
class ClubsRowCard extends StatelessWidget {
  const ClubsRowCard(
      {super.key,
      required this.club,
      required this.busy,
      required this.onOpen,
      required this.onJoin,
      this.mine = false});

  final Map<String, dynamic> club;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final name = (club['name'] as String?) ?? '';
    final category = ClubCategories.labelFor(club['category'] as String?);
    final count = ((club['memberCount'] as num?) ?? 0).toInt();
    final status = (club['myStatus'] as String?) ?? 'NONE';
    final id = ((club['id'] as num?)?.toInt() ?? 0);
    String? applied;
    if (mine && status == 'PENDING') {
      final at = DateTime.tryParse('${club['requestedAt'] ?? ''}')?.toLocal();
      if (at != null) {
        applied = l.p51ApplyDate(DateFormat('d MMM', Localizations.localeOf(context).toString()).format(at));
      }
    }
    final sub = mine && status == 'PENDING'
        ? [if (category.isNotEmpty) category, if (applied != null) applied].join(' · ')
        : [if (category.isNotEmpty) category, l.clubMgmtMemberCount('$count')].join(' · ');

    final trailing = BuPop(
      trigger: status,
      child: BuFadeThrough(
        duration: BuMotion.short,
        child: KeyedSubtree(key: ValueKey<String>('$mine-$status'), child: _trailing(context, status)),
      ),
    );

    return BuPressable(
      scale: .99,
      child: Material(
        color: t.bg,
        child: InkWell(
          onTap: onOpen,
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                ClubsLogo(name: name, id: id, url: club['logoUrl'] as String?),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .38), child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailing(BuildContext context, String status) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final muted = tx.bodySmall!.copyWith(color: t.mut, fontSize: 13);
    Widget text(String s, {bool strong = false}) =>
        Text(s, maxLines: 2, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis, style: strong ? muted.copyWith(fontWeight: FontWeight.w600) : muted);
    if (mine) {
      return switch (status) {
        'PENDING' => text(l.p51AwaitingReply),
        'BANNED' => text(l.clubMgmtBanned),
        _ => text(_roleLabel(l, club['myRole'] as String?), strong: isClubManagerRole(club['myRole'] as String?)),
      };
    }
    switch (status) {
      case 'ACTIVE':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(LucideIcons.check, size: 16, color: t.ok)),
          const SizedBox(width: 4),
          Flexible(child: text(l.clubMgmtYouAreMember)),
        ]);
      case 'PENDING':
        return text(l.clubMgmtRequestSent);
      case 'BANNED':
        return text(l.clubMgmtBanned);
      default:
        return ClubJoinButton(label: l.clubMgmtJoin, busy: busy, onPressed: busy ? null : onJoin);
    }
  }

  static String _roleLabel(AppLocalizations l, String? role) => switch (role) {
        'OWNER' || 'ADMIN' => l.clubMgmtRoleManager,
        'MODERATOR' => l.clubMgmtRoleModerator,
        _ => l.p51RoleMember,
      };
}

/// Tam genişlik çerçeveli düğme (Stitch v3): 48 dp, beyaz dolgu, 1 dp `bdStrong` çerçeve, 16 dp köşe, ink metin.
/// [onPressed] null: pasif (muted metin).
class ClubOutlineButton extends StatelessWidget {
  const ClubOutlineButton({super.key, required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: BuPressable(
        scale: .98,
        enabled: enabled,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: t.bdStrong)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    buHaptic(BuHaptic.selection);
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: BuSize.button,
              child: Center(
                child: busy
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: t.mut))
                    : Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(color: enabled ? t.ink : t.mut, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük çerçeveli "Katıl": 36 dp yüksek, beyaz, `bdStrong` 1 dp çerçeve, 18 dp köşe; dokunma alanı 48 dp.
class ClubJoinButton extends StatelessWidget {
  const ClubJoinButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed == null
            ? null
            : () {
                buHaptic(BuHaptic.light);
                onPressed!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 60, minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 17),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.bdStrong)),
            child: Center(
              widthFactor: 1,
              child: busy
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.mut))
                  : Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortalanmış durum metni (boş / hata): muted metin + marka renkli metin düğmesi. İllüstrasyon yok.
class ClubsStateText extends StatelessWidget {
  const ClubsStateText({super.key, required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w400)),
            if (actionLabel != null) ...[
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.pr, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: onAction,
                child: Text(actionLabel!, style: tx.titleMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yükleniyor iskeleti: 5 satır, 48 dp daire + uzun (%70) ve kısa (%45) çubuk.
class ClubsRowSkeleton extends StatelessWidget {
  const ClubsRowSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.commonLoading,
      liveRegion: true,
      child: BuSkeletonScope(
        child: LayoutBuilder(builder: (context, c) {
          final textW = (c.maxWidth - 40 - 48 - 16).clamp(0.0, double.infinity);
          return Column(
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 8),
                  child: Row(children: [
                    const BuSkeleton.circle(48),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BuSkeleton.line(width: textW * .7, height: 12),
                      const SizedBox(height: 10),
                      BuSkeleton.line(width: textW * .45, height: 10),
                    ]),
                  ]),
                ),
            ],
          );
        }),
      ),
    );
  }
}
