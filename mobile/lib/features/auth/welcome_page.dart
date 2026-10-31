import 'package:flutter/material.dart';

import '../../core/app_gate.dart' show appVersion;
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'widgets/auth_ref.dart';

/// İlk açılışta (cihaz başına bir kez) gösterilen karşılama (Stitch 01 "Karşılama"): koyu lacivert tanıtım kartı,
/// üç özellik satırı, kayıt notu, Giriş yap + Kayıt ol. Sağ üstte TR | EN | AR dil seçici.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final features = <(IconData, Color, Color, String, String)>[
      (LucideIcons.newspaper, t.soft, t.pr, l.welcomeNews, l.p02WelcomeNewsSub),
      (LucideIcons.utensils, t.tint(1).bg, t.tint(1).fg, l.welcomeMenu, l.p02WelcomeMenuSub),
      (LucideIcons.users, t.sf2, t.pr, l.welcomeClubs, l.p02WelcomeClubsSub),
    ];
    return RefPage(
      showBack: false,
      trailing: const _LangPill(),
      bottomPad: 20,
      children: [
        const _Hero(),
        const SizedBox(height: 16),
        for (final f in features) ...[
          RefCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: f.$2, shape: BoxShape.circle),
                  child: Icon(f.$1, color: f.$3, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.$4, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(f.$5, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: t.mut),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        _DomainNote(l.welcomeNote),
        const SizedBox(height: 20),
        RefButton(label: l.loginSubmit, icon: buDirIcon(context, LucideIcons.arrowRight), onPressed: onLogin),
        const SizedBox(height: 12),
        RefButton(label: l.loginRegister, kind: RefButtonKind.secondary, onPressed: onRegister),
        const SizedBox(height: 16),
        Center(
          child: Text(
            trUpper(l.profileVersion(appVersion)),
            style: tx.labelSmall!.copyWith(color: t.mut, letterSpacing: .8, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Sağ üst dil seçici: üç dilimli hap, seçili dilim marka kırmızısı. Dokununca dil hemen değişir.
class _LangPill extends StatelessWidget {
  const _LangPill();

  static const _codes = ['tr', 'en', 'ar'];

  @override
  Widget build(BuildContext context) {
    final lc = LocaleController.current;
    if (lc == null) return const SizedBox.shrink();
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cur = Localizations.localeOf(context).languageCode;
    return Semantics(
      label: context.l10n.welcomeLanguage,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in _codes)
              Semantics(
                button: true,
                selected: c == cur,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: c == cur ? null : () => lc.set(c),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: c == cur ? t.pr : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c.toUpperCase(),
                        style: tx.labelSmall!.copyWith(color: c == cur ? t.onPr : t.mut, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Koyu lacivert tanıtım kartı: marka + iki satırlı başlık + açıklama.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lines = l.welcomeHeadline.split('\n');
    final accent = Color.lerp(t.pr, t.onMedia, .78)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? [t.sf3, t.sf] : [Color.lerp(t.ink, t.pr, .22)!, t.ink],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RefBrandMark(size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BÜ Kampüs', style: tx.titleLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w800)),
                    Text(l.p02BrandSub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.labelSmall!.copyWith(color: t.onMedia.withValues(alpha: .78), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: lines.first),
                  if (lines.length > 1) ...[const TextSpan(text: '\n'), TextSpan(text: lines.sublist(1).join(' '), style: TextStyle(color: accent))],
                ],
              ),
              style: tx.headlineLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w800, height: 1.12),
            ),
          ),
          const SizedBox(height: 10),
          Text(l.welcomeSub, style: tx.bodyMedium!.copyWith(color: t.onMedia.withValues(alpha: .8), height: 1.45)),
        ],
      ),
    );
  }
}

/// "Yalnızca okul e-postası (bingol.edu.tr) ile kayıt olunabilir." kartı; alan adı kalın kırmızı.
class _DomainNote extends StatelessWidget {
  const _DomainNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    const dom = 'bingol.edu.tr';
    final at = text.indexOf(dom);
    final base = tx.bodyMedium!.copyWith(color: t.ink, height: 1.4);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.tint(1).bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.sf, shape: BoxShape.circle),
            child: Icon(LucideIcons.shieldCheck, size: 20, color: t.pr),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: at < 0
                ? Text(text, style: base)
                : Text.rich(
                    TextSpan(style: base, children: [
                      TextSpan(text: text.substring(0, at)),
                      TextSpan(text: dom, style: TextStyle(color: t.pr, fontWeight: FontWeight.w800)),
                      TextSpan(text: text.substring(at + dom.length)),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}
