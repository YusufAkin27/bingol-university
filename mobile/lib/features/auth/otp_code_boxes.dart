import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';

/// Altı kutulu kod girişi: içte tek (görünmez) TextField, üstte 6 kutu çizimi.
/// Tek alan olduğu için yapıştırma ve oneTimeCode otomatik doldurma çalışır.
class OtpCodeBoxes extends StatefulWidget {
  const OtpCodeBoxes({
    super.key,
    required this.controller,
    required this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final VoidCallback onCompleted;
  final bool enabled;
  final bool hasError;

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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      label: context.l10n.authRestCodeLabel,
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focus.requestFocus(),
        child: SizedBox(
          height: 60,
          child: Stack(
            children: [
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: Listenable.merge([widget.controller, _focus]),
                  builder: (context, _) {
                    final text = widget.controller.text;
                    final focused = _focus.hasFocus;
                    return Row(
                      children: List.generate(6, (i) {
                        final active = focused && i == (text.length < 6 ? text.length : 5);
                        final ch = i < text.length ? text[i] : '';
                        final borderColor = widget.hasError
                            ? t.danger
                            : active
                                ? t.pr
                                : t.bd;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.sf,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor, width: active ? 2 : 1),
                              ),
                              child: ch.isNotEmpty
                                  ? Text(ch,
                                      style: BuType.display.copyWith(color: t.ink))
                                  : (active
                                      ? Container(width: 2, height: 28, color: t.pr)
                                      : null),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              // Görünmez giriş alanı (odak, klavye, yapıştırma, otomatik doldurma).
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
    );
  }
}
