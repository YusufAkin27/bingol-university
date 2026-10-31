import 'package:flutter/material.dart';

import '../../../core/api.dart';
import '../../../core/locale_controller.dart';
import '../../../core/session.dart';
import '../../../widgets/bu.dart';
import '../widgets/auth_motion.dart';
import '../widgets/auth_ref.dart';
import 'help_code_page.dart';
import 'public_support_api.dart';

/// Yardım formu (Stitch v3 "24", herkese açık): giriş yapamayan kullanıcı hesapsız talep açar; kod e-postaya gider,
/// sonraki adım kod doğrulama. Alanlar: ad soyad, e-posta (her alan adı), konu (kategori), mesaj. Bal kabağı alanı
/// (`website`) ekranda yoktur ve hep boş gider; `elapsedMs` açılıştan gönderime geçen süredir.
class HelpFormPage extends StatefulWidget {
  const HelpFormPage({super.key, required this.session});

  final Session session;

  @override
  State<HelpFormPage> createState() => _HelpFormPageState();
}

class _HelpFormPageState extends State<HelpFormPage> {
  static const _categories = ['ACCOUNT', 'TECHNICAL', 'CONTENT', 'OTHER'];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  final _opened = Stopwatch()..start();
  String _category = 'ACCOUNT';
  bool _busy = false;
  String? _error;
  String? _retry;
  int _shake = 0;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send(PublicSupportApi api) => api.submit(
        name: _name.text,
        email: _email.text,
        category: _category,
        message: _message.text,
        elapsedMs: _opened.elapsedMilliseconds,
      );

  Future<void> _submit() async {
    if (_busy) return;
    final l = context.l10n;
    if (!(_form.currentState?.validate() ?? false)) {
      authHaptic(AuthHaptic.error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _retry = null;
    });
    final api = PublicSupportApi(widget.session.api);
    try {
      await _send(api);
      if (!mounted) return;
      // Yanıt hep genel (hesap var/yok sızdırmaz): doğrudan kod adımı.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HelpCodePage(session: widget.session, email: _email.text.trim(), resend: () => _send(api)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      authHaptic(AuthHaptic.error);
      var text = errorText(e);
      String? retry;
      if (e is ApiError && e.status == 429 && !e.isNetwork) {
        retry = retryAfterText(e.retryAfter, l);
        text = e.message.isNotEmpty ? e.message : l.coreErrTooMany;
      }
      setState(() {
        _error = text;
        _retry = retry;
        _shake++;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cats = {
      'ACCOUNT': l.supportCatAccount,
      'TECHNICAL': l.supportCatTechnical,
      'CONTENT': l.supportCatContent,
      'OTHER': l.supportCatOther,
    };
    return RefPage(
      children: [
        RefHeading(title: l.p66HelpAction, subtitle: l.p66HelpSub),
        const SizedBox(height: 32),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RefTextField(
                controller: _name,
                label: l.p66FieldName,
                enabled: !_busy,
                maxLength: PublicSupportApi.nameMax,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (v) => validatePublicSupport(name: v ?? '', email: 'a@b.cd', message: 'x' * 10).name == null ? null : l.p66ErrName,
              ),
              const SizedBox(height: 24),
              RefTextField(
                controller: _email,
                label: l.p66FieldEmail,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: (v) => validatePublicSupport(name: 'x', email: v ?? '', message: 'x' * 10).email == null ? null : l.p66ErrEmail,
              ),
              const SizedBox(height: 24),
              Text(l.p66FieldTopic, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories)
                    BuChip(label: cats[c]!, selected: _category == c, onTap: _busy ? null : () => setState(() => _category = c)),
                ],
              ),
              const SizedBox(height: 24),
              RefTextField(
                controller: _message,
                label: l.p66FieldMessage,
                enabled: !_busy,
                minLines: 4,
                maxLines: 6,
                maxLength: PublicSupportApi.messageMax,
                validator: (v) {
                  final e = validatePublicSupport(name: 'x', email: 'a@b.cd', message: v ?? '').message;
                  if (e == null) return null;
                  return e == PublicFieldError.tooLong ? l.p66ErrMsgLong : l.p66ErrMsgShort;
                },
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _message,
                    builder: (_, v, __) => Text('${v.text.characters.length}/${PublicSupportApi.messageMax}',
                        style: tx.bodySmall!.copyWith(color: t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              RefButton(label: l.authNext, busy: _busy, onPressed: _submit),
              AnimatedSize(
                duration: BuMotion.of(context, BuMotion.short),
                curve: BuMotion.decelerate,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: AuthShake(
                          trigger: _shake,
                          child: _retry != null
                              ? RefBanner(_error!, key: ValueKey('help-error-$_error'), tone: RefTone.warn, sub: _retry)
                              : RefBanner(_error!, key: ValueKey('help-error-$_error')),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(l.p66ReplyNote, style: tx.bodySmall!.copyWith(color: t.mut))),
            ],
          ),
        ),
      ],
    );
  }
}
