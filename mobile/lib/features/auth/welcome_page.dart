import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/app_gate.dart' show appVersion;
import '../../widgets/bu.dart';
import 'widgets/auth_ref.dart';

/// İlk açılışta (cihaz başına bir kez) gösterilen karşılama (Stitch v3 "01 Karşılama"): zemin düz, tek mesaj
/// (iki satırlı başlık + tek satır açıklama), üç nokta-metin satırı, altta tek birincil düğme (Giriş yap), düz metin
/// ikincil (Kayıt ol), kayıt notu ve sürüm. Hero kartı, logo karosu, kart/ikon ve bilgi kutusu yok. Sağ üstte TR | EN | AR.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onLogin, required this.onRegister});

  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final features = [l.welcomeNews, l.welcomeMenu, l.welcomeClubs];
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kRefPad),
                    child: BuStaggerScope(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(alignment: AlignmentDirectional.centerEnd, child: _LangPill()),
                          const SizedBox(height: 72),
                          // Tek mesaj: iki satırlı başlık + tek satır açıklama + üç kısa satır.
                          BuStaggerItem(
                            index: 0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(l.welcomeHeadline,
                                      style: tx.headlineLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1.15)),
                                ),
                                const SizedBox(height: 16),
                                Text(l.welcomeSub, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.5)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          for (var i = 0; i < features.length; i++)
                            BuStaggerItem(
                              index: i + 1,
                              // Yalnız bilgi (dokunulmaz): ikon/ok yok, solda küçük nokta.
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(color: t.ink, shape: BoxShape.circle)),
                                    const SizedBox(width: 16),
                                    Expanded(child: Text(features[i], style: tx.bodyLarge!.copyWith(color: t.ink))),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 64),
                          BuStaggerItem(
                            index: features.length + 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RefButton(label: l.loginSubmit, onPressed: onLogin),
                                const SizedBox(height: 8),
                                RefButton(label: l.loginRegister, kind: RefButtonKind.ghost, onPressed: onRegister),
                                const SizedBox(height: 8),
                                _DomainNote(l.welcomeNote),
                                const SizedBox(height: 16),
                                Center(child: Text(l.profileVersion(appVersion), style: tx.bodySmall!.copyWith(color: t.mut))),
                                const SizedBox(height: 24),
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
        decoration: const BoxDecoration(),
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
                    // Dokunma hedefi 40 dp yükseklik (sabit: hap 44 dp'de kalır, üst çubuğu doldurmaz), >= 44 dp genişlik.
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 40, maxHeight: 40),
                    child: AnimatedContainer(
                      duration: BuMotion.of(context, BuMotion.short),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: c == cur ? t.soft : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        c.toUpperCase(),
                        style: tx.labelMedium!.copyWith(color: c == cur ? t.pr : t.mut, fontWeight: c == cur ? FontWeight.w700 : FontWeight.w500),
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
                TextSpan(text: dom, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                TextSpan(text: text.substring(at + dom.length)),
              ]),
              textAlign: TextAlign.center,
            ),
    );
  }
}
