import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../posts/post_text_rules.dart';
import 'club_detail_parts.dart';
import 'kulup_widgets.dart';

/// Kulüp detayı kartları (K7, referans 27-01, 28-02, 28-04): rol rozeti, gönderi kartı, üye satırı, yazma kutusu.

/// Sahip/yönetici/moderatör rozeti (üye satırlarında); sade üye için null.
/// Referans: yönetici kırmızı tonlu, moderatör mavi tonlu + kalkan.
Widget? clubRoleBadge(BuildContext context, String? role) {
  final l = context.l10n;
  final blue = context.bu.tint(1);
  return switch (role) {
    'OWNER' || 'ADMIN' => KulupRoleBadge(l.clubRoleOwner),
    'MODERATOR' => KulupRoleBadge(l.clubRoleModerator, icon: LucideIcons.shield, bg: blue.bg, fg: blue.fg),
    _ => null,
  };
}

/// Gönderi kartı: yazar, zaman, sabit rozeti, ⋯ menüsü, metin, isteğe bağlı görsel, (varsa) beğeni sayısı.
/// Yorum alanı/sayacı yoktur.
class ClubPostCard extends StatelessWidget {
  const ClubPostCard({super.key, required this.post, this.onMenu});

  final Map<String, dynamic> post;

  /// null: menü gösterilmez (üye olmayan).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final p = post;
    final img = fileUrl(p['imageUrl']?.toString());
    final pinned = p['pinned'] == true;
    final text = (p['text'] ?? '').toString();
    final likes = (p['likeCount'] as num?)?.toInt();
    final badge = clubRoleBadge(context, p['authorRole']?.toString());
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KulupAvatar(name: p['authorName']?.toString(), url: p['authorAvatarUrl']?.toString(), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text((p['authorName'] ?? '').toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                        if (badge != null) badge,
                      ],
                    ),
                    Text(relativeTime(p['createdAt']?.toString(), context: context),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.mut, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (pinned) ...[const SizedBox(width: 6), _PinnedPill(label: context.l10n.clubPinned)],
              if (onMenu != null)
                ClubRoundButton(icon: LucideIcons.ellipsis, tooltip: context.l10n.clubPostActions, onTap: onMenu, plain: true, size: 40)
              else
                const SizedBox(width: 8),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Text(text, style: tx.bodyLarge!.copyWith(height: 1.45, color: t.ink)),
            ),
          ],
          if (img != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: BuImage(p['imageUrl']?.toString(), width: double.infinity, height: double.infinity, radius: BuRadius.md, placeholderIcon: LucideIcons.image),
              ),
            ),
          ],
          if (likes != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(LucideIcons.heart, size: 20, color: p['liked'] == true ? t.pr : t.mut)),
                  const SizedBox(width: 8),
                  Text(context.l10n.p11LikeCount('$likes'), style: tx.labelLarge!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedPill extends StatelessWidget {
  const _PinnedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(LucideIcons.pin, size: 12, color: t.onSoft)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.onSoft, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// "Bölüm · N. sınıf" alt satırı: alanlar sunucuda yoksa (BACKEND-ISTEK) boş döner.
String clubMemberSubtitle(BuildContext context, Map<String, dynamic> m) {
  final dep = (m['department'] ?? m['faculty'] ?? '').toString().trim();
  final y = (m['classYear'] as num?)?.toInt();
  return [if (dep.isNotEmpty) dep, if (y != null && y > 0) context.l10n.profileGradeYear('$y')].join(' · ');
}

/// Üye satırı kartı: avatar (+ rol rozeti köşede), ad + rol etiketi, bölüm · sınıf; [trailing] sonda.
class ClubMemberTile extends StatelessWidget {
  const ClubMemberTile({super.key, required this.member, this.trailing, this.nameFallback});

  final Map<String, dynamic> member;
  final Widget? trailing;
  final String? nameFallback;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final m = member;
    final role = m['role']?.toString();
    final badge = clubRoleBadge(context, role);
    final sub = clubMemberSubtitle(context, m);
    return BuCard(
      padding: EdgeInsetsDirectional.fromSTEB(14, 14, trailing == null ? 14 : 6, 14),
      child: Row(
        children: [
          ClubRoleAvatar(name: m['displayName']?.toString(), url: m['avatarUrl']?.toString(), role: role),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text((m['displayName'] ?? nameFallback ?? context.l10n.clubUser).toString(),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                    if (badge != null) badge,
                  ],
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(sub, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Üye avatarı: sağ altta rol rozeti (yönetici: yıldız, moderatör: kalkan).
class ClubRoleAvatar extends StatelessWidget {
  const ClubRoleAvatar({super.key, required this.name, this.url, this.role, this.size = 52, this.ring});

  final String? name;
  final String? url;
  final String? role;
  final double size;

  /// Rozet çerçevesi rengi (kart zemini); varsayılan `sf`.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final owner = role == 'OWNER' || role == 'ADMIN';
    final mod = role == 'MODERATOR';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          KulupAvatar(name: name, url: url, size: size),
          if (owner || mod)
            PositionedDirectional(
              end: -3,
              bottom: -3,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: owner ? t.pr : t.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: ring ?? t.sf, width: 2),
                ),
                child: Icon(owner ? LucideIcons.star : LucideIcons.shield, size: 11, color: owner ? t.onPr : t.bg),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Yazma kutusu

/// Gönderi yazma kutusu (referans 28-04): avatar + tek satır metin (en çok 7 kelime), altta "Görsel ekle" ve "Paylaş";
/// görsel önizlemesi ve satır içi uyarılar.
class ClubComposer extends StatelessWidget {
  const ClubComposer({
    super.key,
    required this.controller,
    required this.image,
    required this.sending,
    required this.needText,
    required this.onChanged,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSend,
    this.selfName,
  });

  final TextEditingController controller;
  final PreparedImage? image;
  final bool sending;

  /// Görsel var ama yazı boş denendi (sunucu yazıyı zorunlu tutar): uyarı kırmızılaşır.
  final bool needText;
  final VoidCallback onChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  /// Yazarın adı (avatar baş harfleri için); yoksa kişi simgesi.
  final String? selfName;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final text = controller.text;
    final words = postWordCount(text);
    final ok = postTextOk(text);
    final hasText = text.trim().isNotEmpty;
    final canSend = !sending && ok && (hasText || image != null);
    final missingText = image != null && !hasText;
    return BuCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Stack(
                alignment: AlignmentDirectional.topEnd,
                children: [
                  ClipRRect(
                    borderRadius: BuRadius.bMd,
                    child: Image.memory(image!.bytes, width: double.infinity, height: 168, fit: BoxFit.cover, cacheWidth: 900, gaplessPlayback: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ClubRoundButton(icon: LucideIcons.x, tooltip: l10n.clubRemoveImage, onTap: onRemoveImage, onCover: true, size: 36),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              BuAvatar(name: selfName, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
                  alignment: AlignmentDirectional.centerStart,
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 1,
                    onChanged: (_) => onChanged(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kPostMaxChars),
                      FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                    ],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => canSend ? onSend() : null,
                    style: tx.bodyLarge!.copyWith(color: t.ink),
                    decoration: InputDecoration(
                      hintText: l10n.clubWriteHint,
                      hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _TonalPill(label: l10n.clubAddImage, icon: LucideIcons.imagePlus, onTap: sending ? null : onPickImage)),
              const SizedBox(width: 12),
              BuButton(label: l10n.clubShare, compact: true, busy: sending, onPressed: canSend ? onSend : null),
            ],
          ),
          if (missingText)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(l10n.clubPostTextRequired,
                    key: const ValueKey('clubPostTextRequired'),
                    style: tx.bodySmall!.copyWith(color: needText ? t.danger : t.mut)),
              ),
            ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
              child: Text(
                ok ? l10n.gonderiWordCount(words.toString(), kPostMaxWords.toString()) : l10n.gonderiWordLimit(kPostMaxWords.toString()),
                style: tx.bodySmall!.copyWith(color: ok ? t.mut : t.danger),
              ),
            ),
        ],
      ),
    );
  }
}

/// Gri tonlu küçük hap düğme (simge kırmızı): "Görsel ekle".
class _TonalPill extends StatelessWidget {
  const _TonalPill({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final on = onTap != null;
    return Semantics(
      button: true,
      enabled: on,
      label: label,
      child: ExcludeSemantics(
        child: BuPressable(
          enabled: on,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: on ? t.pr : t.mut),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
