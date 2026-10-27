import 'package:flutter/material.dart';

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
  return null;
}

/// Kırmızı "hero" başlıklı, kaydırılabilir kimlik ekranı iskeleti (tasarım: Main / A-Register).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.of(context).padding.top;
    final side = showBack ? 24.0 : 28.0;

    return Scaffold(
      backgroundColor: t.bg,
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(side, top + (showBack ? 12 : 24), side, 28),
                  decoration: BoxDecoration(
                    gradient: t.hero,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showBack)
                        Semantics(
                          button: true,
                          label: context.l10n.authBack,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.maybePop(context),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(buDirIcon(context, LucideIcons.arrowLeft), color: Colors.white, size: 20),
                            ),
                          ),
                        )
                      else
                        const BuMark(height: 56),
                      SizedBox(height: showBack ? 22 : 28),
                      Text(
                        title,
                        style: BuType.display.copyWith(color: Colors.white, height: 1.15),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style: (showBack ? BuType.label : BuType.body).copyWith(color: Colors.white.withValues(alpha: 0.95), height: 1.45),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 24, side, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tasarımdaki 54 px yüksek, yuvarlak alan görünümü (soluk ipucu metni + öncü simge).
InputDecoration authFieldDecoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  final t = context.bu;
  return InputDecoration(
    hintText: hint,
    hintStyle: BuType.body.copyWith(color: t.mut),
    prefixIcon: Icon(icon, size: 18, color: t.mut),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    constraints: const BoxConstraints(minHeight: 54),
  );
}

/// Şifre alanı: göster/gizle düğmeli.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Şifre',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
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
        hint: widget.label,
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
  const IdentifierField({super.key, required this.controller, this.onSubmitted, this.enabled = true});

  final TextEditingController controller;
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
          validator: validateIdentifier,
          style: BuType.body.copyWith(color: t.ink),
          onFieldSubmitted: (_) => onSubmitted?.call(),
          decoration: deco.copyWith(
            helperText: '226051015 ya da ad.soyad@bingol.edu.tr',
            helperMaxLines: 2,
            helperStyle: BuType.caption.copyWith(color: t.mut),
            suffixText: isStudentNumberInput(value.text) ? '@bingol.edu.tr' : null,
            suffixStyle: BuType.body.copyWith(color: t.mut),
          ),
        );
      },
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
