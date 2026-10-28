import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/locale_controller.dart';
import '../../core/identifier.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../core/typography.dart';

final _emailRe = RegExp(r'^[a-z0-9._%+\-]+@([a-z0-9\-]+\.)*bingol\.edu\.tr$');

String? validateEmail(String? v) {
  final s = (v ?? '').trim().toLowerCase();
  if (s.isEmpty) return 'E-posta adresinizi girin.';
  if (!_emailRe.hasMatch(s)) return 'Yalnızca bingol.edu.tr uzantılı adres kullanılabilir.';
  return null;
}

String? validateNewPassword(String? v) {
  final s = v ?? '';
  if (s.length < 8) return 'Şifre en az 8 karakter olmalı.';
  if (s.length > 72) return 'Şifre en çok 72 karakter olabilir.';
  if (utf8.encode(s).length > 72) return 'Şifre en fazla 72 bayt olabilir.';
  return null;
}

/// Dile göre hata metni veren yeni şifre doğrulayıcı (kuralları [validateNewPassword] ile aynı).
String? Function(String?) newPasswordValidator(BuildContext context) {
  final l = context.l10n;
  return (v) {
    final s = v ?? '';
    if (s.length < 8) return l.authPwMinErr;
    if (s.length > 72) return l.authPwMaxErr;
    // Sunucu sınırı 72 BAYT'tır: Türkçe/Arapça karakterler birden çok bayt tutar (PASSWORD_TOO_LONG).
    if (utf8.encode(s).length > 72) return l.errPasswordTooLong;
    return null;
  };
}

/// Kimlik ekranları iskeleti: düz zemin, sağ üstte soluk dekor daire, sola hizalı başlık. Üstte geri düğmesi
/// (ve isteğe bağlı sağda [trailing] + altında [progress]) ya da küçük logo; klavye açılınca logo gizlenir.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = false,
    this.minimal = false,
    this.trailing,
    this.progress,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Eski imza uyumu için korunur; tüm kimlik ekranları aynı (sade) düzeni kullanır.
  final bool minimal;

  /// Geri düğmesinin karşısında (sağda) görünen küçük metin/parça (ör. "Adım 1/3").
  final Widget? trailing;

  /// Üst satırın altındaki ilerleme çubuğu.
  final Widget? progress;

  /// Başlığın üstünde görünen ikon karosu (şifre sıfırlama / kod ekranları).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.of(context).padding.top;
    final keyboard = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          PositionedDirectional(
            top: -120,
            end: -120,
            child: ExcludeSemantics(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.soft),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(28, top + (showBack ? 12 : (keyboard ? 16 : 36)), 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showBack)
                        Row(
                          children: [
                            Semantics(
                              button: true,
                              label: context.l10n.authBack,
                              child: Material(
                                color: t.sf,
                                shape: CircleBorder(side: BorderSide(color: t.bd)),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => Navigator.maybePop(context),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: t.ink, size: 20),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (trailing != null) trailing!,
                          ],
                        )
                      else if (!keyboard)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SvgPicture.asset('assets/branding/mark.svg',
                              width: 48, height: 48, semanticsLabel: 'BÜ Kampüs'),
                        ),
                      if (progress != null) ...[const SizedBox(height: 20), progress!],
                      SizedBox(height: showBack ? 28 : (keyboard ? 12 : 32)),
                      if (icon != null) ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: t.sf,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: t.bd),
                              boxShadow: [
                                BoxShadow(color: t.ink.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -12),
                              ],
                            ),
                            child: Icon(icon, color: t.pr, size: 26),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        title,
                        style: BuType.display.copyWith(
                            color: t.ink, fontSize: keyboard ? 28 : 30, height: 1.12, letterSpacing: -0.5, fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(subtitle!, style: BuType.body.copyWith(color: t.mut, fontSize: 15, height: 1.5)),
                      ],
                      SizedBox(height: keyboard ? 20 : 28),
                      ...children,
                    ],
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

/// 56 px yüksek, 16 px yuvarlak alan görünümü (soluk ipucu metni + öncü simge); odakta kırmızı çerçeve.
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  final t = context.bu;
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: BuType.body.copyWith(color: t.mut, fontSize: 15),
    prefixIcon: Icon(icon, size: 20, color: t.mut),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    constraints: const BoxConstraints(minHeight: 56),
    border: b(t.bd),
    enabledBorder: b(t.bd),
    focusedBorder: b(t.pr, 2),
    errorBorder: b(t.danger),
    focusedErrorBorder: b(t.danger, 2),
  );
}

/// Ana eylem düğmesi: 56 px, 18 px yuvarlak, altında yumuşak kırmızı gölge. İçte gerçek [FilledButton].
class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.onPressed, required this.label, this.busy = false});

  final VoidCallback? onPressed;
  final String label;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: t.pr.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -10)],
      ),
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: BusyLabel(busy: busy, label: label),
      ),
    );
  }
}

/// Parçalı ilerleme çubuğu (kayıt adımları).
class AuthProgress extends StatelessWidget {
  const AuthProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= step ? t.pr : t.bd,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Şifre alanı: göster/gizle düğmeli.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String? label;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      style: BuType.body.copyWith(color: t.ink),
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: authFieldDecoration(
        context,
        hint: widget.label ?? context.l10n.authPasswordLabel,
        icon: LucideIcons.lock,
        suffix: IconButton(
          tooltip: _hidden ? context.l10n.authShowPassword : context.l10n.authHidePassword,
          icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: t.mut),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    );
  }
}

/// Okul numarası ya da e-posta alanı. Yalnız rakam yazılırken sona soluk `@bingol.edu.tr` soneki görünür;
/// sunucuya olduğu gibi (numara ya da tam e-posta) gönderilir.
class IdentifierField extends StatelessWidget {
  const IdentifierField({super.key, required this.controller, this.onSubmitted, this.enabled = true, this.validator});

  final TextEditingController controller;

  /// Verilirse [validateIdentifier] yerine kullanılır (kayıt: + etiketi ve sunucu hatası için).
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final deco = authFieldDecoration(context, hint: context.l10n.authIdHint, icon: LucideIcons.mail);
        return TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          validator: validator ?? validateIdentifier,
          style: BuType.body.copyWith(color: t.ink),
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: deco.copyWith(
            suffixText: isStudentNumberInput(value.text) ? '@bingol.edu.tr' : null,
            suffixStyle: BuType.body.copyWith(color: t.mut),
          ),
        );
      },
    );
  }
}

/// Form bölümü başlığı (küçük, büyük harfsiz etiket + ince ayraç).
class AuthSectionLabel extends StatelessWidget {
  const AuthSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(text, style: BuType.label.copyWith(color: t.mut)),
          const SizedBox(width: 12),
          Expanded(child: Divider(height: 1, color: t.bd)),
        ],
      ),
    );
  }
}

/// Şifre gücü: 3 parçalı çubuk + metin (renge ek olarak metin, erişilebilirlik için).
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    var s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12 || (RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'\d').hasMatch(password))) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password) && password.length >= 8 ||
        (password.length >= 12 && RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'\d').hasMatch(password))) {
      s++;
    }
    return s == 0 ? 1 : s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final t = context.bu;
    final score = _score;
    // WCAG AA belirteçleri: danger / uyarı (amber) / ok; ham Colors.* açık temada 4.5:1 altındaydı.
    final warn = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFC66B) : const Color(0xFF8A5200);
    final color = score == 1 ? t.danger : (score == 2 ? warn : t.ok);
    final label = score == 1
        ? context.l10n.authPwWeak
        : (score == 2 ? context.l10n.authPwFair : context.l10n.authPwStrong);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10, start: 2, end: 2),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i < score ? color : t.bd,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 4),
          ],
          const SizedBox(width: 12),
          Text(label, style: BuType.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Şifre kuralı satırı: sağlanınca yeşil onay, aksi halde boş halka (renge ek olarak metin).
class PasswordRule extends StatelessWidget {
  const PasswordRule({super.key, required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final c = ok ? t.ok : t.mut;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? t.ok.withValues(alpha: 0.15) : null,
            border: ok ? null : Border.all(color: t.bd, width: 1.5),
          ),
          child: ok ? Icon(LucideIcons.check, size: 12, color: c) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: BuType.body.copyWith(color: c, fontSize: 14))),
      ],
    );
  }
}

/// Hata / bilgi kutusu (form üstünde).
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.error = true});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final cs = Theme.of(context).colorScheme;
    final bg = error ? cs.errorContainer : t.soft;
    final fg = error ? t.danger : t.onSoft;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(error ? LucideIcons.circleAlert : LucideIcons.info, color: fg, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: BuType.body.copyWith(color: fg, height: 1.35))),
        ],
      ),
    );
  }
}

/// Düğme içi yükleniyor göstergesi.
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.label});

  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(label);
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: context.bu.onPr),
    );
  }
}
