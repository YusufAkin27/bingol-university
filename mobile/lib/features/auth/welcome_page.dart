import 'package:flutter/material.dart';

import '../../core/app_gate.dart' show appVersion;
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'widgets/auth_ref.dart';

/// İlk açılışta (cihaz başına bir kez) gösterilen karşılama: sakin nötr zemin, solda küçük marka karosu, sağda
/// TR | EN | AR; tek mesaj (başlık + açıklama), beyaz tek kart içinde üç özellik satırı, altta birincil düğme
/// (Giriş yap), ikincil çerçeveli düğme (Kayıt ol), kayıt notu ve sürüm. Marka rengi yalnız küçük vurgularda
/// (karo, simge zemini, birincil düğme); büyük kırmızı alan, gradyan ve güçlü gölge yok.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final features = [
      (BuIcons.newspaper, l.welcomeNews),
      (BuIcons.utensils, l.welcomeMenu),
      (BuIcons.users, l.welcomeClubs),
    ];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kRefPad),
                    child: BuStaggerScope(
                      // Boşluk (Spacer) için sınırlı yükseklik: düğmeler kısa ekranda içeriğin altında, uzunda dipte durur.
                      child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              RefBrandMark(size: 40),
                              Spacer(),
                              _LangPill(),
                            ],
                          ),
                          const SizedBox(height: 56),
                          BuStaggerItem(
                            index: 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(l.welcomeHeadline,
                                      style: tx.headlineLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.15)),
                                ),
                                const SizedBox(height: 12),
                                Text(l.welcomeSub, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          BuStaggerItem(
                            index: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: t.sf,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: t.bd),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < features.length; i++) ...[
                                    if (i > 0) Divider(height: 1, thickness: 1, indent: 68, color: t.bdSubtle),
                                    _FeatureRow(icon: features[i].$1, label: features[i].$2),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 40),
                          BuStaggerItem(
                            index: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RefButton(label: l.loginSubmit, onPressed: onLogin),
                                const SizedBox(height: 12),
                                RefButton(label: l.loginRegister, kind: RefButtonKind.secondary, onPressed: onRegister),
                                const SizedBox(height: 16),
                                _DomainNote(l.welcomeNote),
                                const SizedBox(height: 12),
                                Center(child: Text(l.profileVersion(appVersion), style: tx.bodySmall!.copyWith(color: t.mut))),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bilgi satırı (dokunulmaz): yumuşak zeminli küçük simge karosu + metin.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: t.onSoft),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

/// Sağ üst dil seçici: üç dilimli hap, seçili dilim yumuşak marka zemini. Dokununca dil hemen değişir.
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
                  // Dokunma hedefi: >= 44 dp genişlik, 40 dp yükseklik (üst çubuğu doldurmaz).
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 40, maxHeight: 40),
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    curve: AppMotion.standard,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: c == cur ? t.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      c.toUpperCase(),
                      style: tx.labelMedium!.copyWith(color: c == cur ? t.onSoft : t.mut, fontWeight: c == cur ? FontWeight.w400 : FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Yalnızca okul e-postası (bingol.edu.tr) ile kayıt olunabilir." tek sakin satır; alan adı kalın.
class _DomainNote extends StatelessWidget {
  const _DomainNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    const dom = 'bingol.edu.tr';
    final at = text.indexOf(dom);
    final base = tx.bodySmall!.copyWith(color: t.mut, height: 1.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: at < 0
          ? Text(text, textAlign: TextAlign.center, style: base)
          : Text.rich(
              TextSpan(style: base, children: [
                TextSpan(text: text.substring(0, at)),
                TextSpan(text: dom, style: TextStyle(color: t.ink, fontWeight: FontWeight.w400)),
                TextSpan(text: text.substring(at + dom.length)),
              ]),
              textAlign: TextAlign.center,
            ),
    );
  }
}
