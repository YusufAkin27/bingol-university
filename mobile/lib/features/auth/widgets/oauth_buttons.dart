import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_motion.dart';

/// Google marka yönergesi (developers.google.com/identity/branding-guidelines) ZORUNLU kıldığı düğme renkleri:
/// açık temada beyaz zemin / #747775 çerçeve / #1F1F1F yazı, koyu temada #131314 zemin / #8E918F çerçeve / #E3E3E3 yazı.
/// Bunlar uygulama token'ı DEĞİL, marka şartıdır (başka yerde kullanılmaz); "G" resmî çok renkli logodur.
class _GoogleBrand {
  const _GoogleBrand._(this.fill, this.border, this.text);

  static const light = _GoogleBrand._(Color(0xFFFFFFFF), Color(0xFF747775), Color(0xFF1F1F1F));
  static const dark = _GoogleBrand._(Color(0xFF131314), Color(0xFF8E918F), Color(0xFFE3E3E3));

  final Color fill;
  final Color border;
  final Color text;
}

/// "Google ile devam et": resmî çok renkli G logosu + Google yönergesine uygun açık/koyu düğme. [onPressed] null ya da
/// [busy] iken dokunulmaz; yüklenirken logo yerine çember görünür. Hedef yükseklik 48 dp.
class GoogleContinueButton extends StatelessWidget {
  const GoogleContinueButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final brand = Theme.of(context).brightness == Brightness.dark ? _GoogleBrand.dark : _GoogleBrand.light;
    final tx = Theme.of(context).textTheme;
    final enabled = onPressed != null && !busy;
    final shape = RoundedRectangleBorder(borderRadius: BuRadius.bControl, side: BorderSide(color: brand.border));
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !busy ? .5 : 1,
        child: Material(
          color: brand.fill,
          shape: shape,
          child: InkWell(
            key: const ValueKey('oauth-google'),
            customBorder: shape,
            onTap: enabled
                ? () {
                    authHaptic(AuthHaptic.tap);
                    onPressed!();
                  }
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: busy
                          ? CircularProgressIndicator(strokeWidth: 2.2, color: brand.text)
                          : SvgPicture.asset('assets/branding/google_g.svg', width: 20, height: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: tx.bodyLarge!.copyWith(color: brand.text, fontWeight: BuType.emphasisWeight, height: 1.2)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Apple ile devam et": iOS'ta resmî `SignInWithAppleButton` (Apple HIG: açık temada siyah, koyu temada beyaz düğme).
/// Yüklenirken aynı renklerde çember gösterilir. Android'de bu düğme çizilmez (üst katman gizler).
class AppleContinueButton extends StatelessWidget {
  const AppleContinueButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !busy;
    // Apple HIG: siyah zeminde beyaz, beyaz zeminde siyah. Koyu temada beyaz düğme zemin ile ayrışır.
    final style = dark ? SignInWithAppleButtonStyle.white : SignInWithAppleButtonStyle.black;
    final spinnerColor = dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final fill = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !busy ? .5 : 1,
        child: busy
            ? Container(
                key: const ValueKey('oauth-apple-busy'),
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fill, borderRadius: BuRadius.bControl),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: spinnerColor)),
              )
            : KeyedSubtree(
                key: const ValueKey('oauth-apple'),
                child: SignInWithAppleButton(
                  text: label,
                  height: height,
                  style: style,
                  borderRadius: BuRadius.bControl,
                  onPressed: enabled
                      ? () {
                          authHaptic(AuthHaptic.tap);
                          onPressed!();
                        }
                      : null,
                ),
              ),
      ),
    );
  }
}

/// İnce ayırıcı: ──── veya ────
class OAuthOrDivider extends StatelessWidget {
  const OAuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: t.bd)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(context.l10n.oaOr, style: tx.bodyMedium!.copyWith(color: t.mut)),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: t.bd)),
      ],
    );
  }
}
