import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'widgets/auth_motion.dart';

/// Altı kutulu kod girişi: içte tek (görünmez) TextField, üstte 6 kutu çizimi.
/// Tek alan olduğu için yapıştırma ve oneTimeCode otomatik doldurma çalışır. Kutular: odak halkası,
/// rakam girince "yaylanma", hata durumunda sarsıntı + kırmızı çerçeve; altta "Yapıştır" kısayolu.
class OtpCodeBoxes extends StatefulWidget {
  const OtpCodeBoxes({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.hasError = false,
    this.shakeTrigger = 0,
    this.showPaste = true,
  });

  final TextEditingController controller;
  final VoidCallback onCompleted;
  final bool enabled;
  final bool hasError;

  /// Artınca kutular sarsılır (yanlış kod).
  final int shakeTrigger;
  final bool showPaste;

  @override
  State<OtpCodeBoxes> createState() => _OtpCodeBoxesState();
}

class _OtpCodeBoxesState extends State<OtpCodeBoxes> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    authHaptic(AuthHaptic.tap);
    String? text;
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {}
    final digits = (text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final code = digits.length > 6 ? digits.substring(0, 6) : digits;
    widget.controller.value = TextEditingValue(text: code, selection: TextSelection.collapsed(offset: code.length));
    if (code.length == 6) widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => Row(
            children: [
              Expanded(
                child: Text(context.l10n.authRestCodeLabel, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
              ),
              if (widget.showPaste && widget.enabled && widget.controller.text.length < 6)
                TextButton.icon(
                  onPressed: _paste,
                  style: TextButton.styleFrom(
                    foregroundColor: t.pr,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  icon: Icon(LucideIcons.clipboardPaste, size: 18, color: t.pr),
                  label: Text(context.l10n.authPaste, style: tx.labelLarge!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: context.l10n.authRestCodeLabel,
          textField: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focus.requestFocus(),
            onLongPress: widget.enabled ? _paste : null,
            // Kod rakamları her dilde soldan sağa dizilir (RTL'de kutular aynalanmaz).
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: AuthShake(
                trigger: widget.shakeTrigger,
                child: SizedBox(
                  height: 52,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: Listenable.merge([widget.controller, _focus]),
                          builder: (context, _) {
                            final text = widget.controller.text;
                            final focused = _focus.hasFocus && widget.enabled;
                            final activeIndex = text.length < 6 ? text.length : 5;
                            return Row(
                              children: List.generate(6, (i) {
                                final active = focused && i == activeIndex;
                                final ch = i < text.length ? text[i] : '';
                                final filled = ch.isNotEmpty;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      curve: Curves.easeOut,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: active ? t.sf : t.sf2,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: active ? BuElevation.of(context, 2) : const [],
                                      ),
                                      child: filled
                                          ? Text(ch, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))
                                          : (active
                                              ? Container(width: 2, height: 24, decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(1)))
                                              : null),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                      // Görünmez giriş alanı (odak, klavye, otomatik doldurma).
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            enabled: widget.enabled,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            enableInteractiveSelection: false,
                            showCursor: false,
                            autocorrect: false,
                            enableSuggestions: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onChanged: (v) {
                              if (v.length == 6) widget.onCompleted();
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                              filled: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
