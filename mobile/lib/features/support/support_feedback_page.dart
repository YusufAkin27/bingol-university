import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../../l10n/app_localizations.dart';
import '../profile/profily_widgets.dart';
import 'destek_widgets.dart';
import 'support_common.dart';
import '../../core/typography.dart';

/// Geri bildirim formu + gönderdiklerim listesi (imleçli).
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.session, this.initialCategory = 'BUG'});

  final Session session;
  final String initialCategory;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category = const ['SUGGESTION', 'BUG'].contains(widget.initialCategory) ? widget.initialCategory : 'OTHER';
  bool _busy = false;
  String? _formError;

  final List<Map<String, dynamic>> _mine = [];
  int? _next;
  bool _loadingMine = true;
  bool _more = false;
  Object? _mineError;

  @override
  void initState() {
    super.initState();
    _loadMine(reset: true);
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine({bool reset = false}) async {
    if (!reset) {
      if (_next == null || _more) return;
      setState(() => _more = true);
    }
    try {
      final q = !reset && _next != null ? '&cursor=$_next' : '';
      final r = await widget.session.api.get('/feedback/mine?size=20$q') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (reset) _mine.clear();
        _mine.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
        _next = (r['nextCursor'] as num?)?.toInt();
        _mineError = null;
        _loadingMine = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mineError = e;
        _loadingMine = false;
        _more = false;
      });
    }
  }

  Future<void> _submit() async {
    final s = _subject.text.trim();
    final m = _message.text.trim();
    if (s.isEmpty || m.isEmpty) {
      setState(() => _formError = context.l10n.supportFillFields);
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await widget.session.api.post('/feedback', {
        'category': _category,
        'subject': s,
        'message': m,
        'platform': 'ANDROID',
      });
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      supportSnack(context, context.l10n.supportFeedbackThanks);
      setState(() => _busy = false);
      _loadMine(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = supportError(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.supportFeedbackTitle, onBack: () => Navigator.pop(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadMine(reset: true),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Text(l.profilyardFbIntro, style: BuType.body.copyWith(fontSize: 13.5, height: 1.45, color: t.mut)),
              SupportLabel(l.profilyardFbType, form: true),
              Row(children: [
                for (final (i, o) in _types(l).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ProfilyTypeChip(
                      label: o.$2,
                      icon: o.$3,
                      selected: _category == o.$1,
                      onTap: () => setState(() => _category = o.$1),
                    ),
                  ),
                ],
              ]),
              SupportLabel(l.profilyardFbTitle, form: true),
              ProfilyField(controller: _subject, hint: l.profilyardFbTitleHint, label: l.profilyardFbTitle, maxLength: 80),
              SupportLabel(l.profilyardFbMessage, form: true),
              ProfilyField(
                controller: _message,
                hint: l.profilyardFbMessageHint,
                label: l.profilyardFbMessage,
                maxLength: 1000,
                minLines: 5,
                maxLines: 8,
                counter: true,
              ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_formError!, style: BuType.caption.copyWith(color: t.danger)),
                ),
              SupportLabel(l.supportLabelMine, form: true),
              ..._mineList(context, t),
            ]),
          ),
        ),
        DestekBottomBar(
          child: ProfilyPrimaryButton(label: l.supportSend, icon: LucideIcons.send, busy: _busy, onPressed: _submit),
        ),
      ]),
    );
  }

  /// Tasarımdaki üç tür çipi (Öneri / Hata / Diğer).
  List<(String, String, IconData)> _types(AppLocalizations l) => [
        ('SUGGESTION', l.supportFbSuggestion, LucideIcons.lightbulb),
        ('BUG', l.supportFbBug, LucideIcons.triangleAlert),
        ('OTHER', l.supportCatOther, LucideIcons.messageCircle),
      ];

  List<Widget> _mineList(BuildContext context, BuTokens t) {
    if (_loadingMine) {
      return [const Padding(padding: EdgeInsets.all(24), child: LoadingView())];
    }
    if (_mineError != null && _mine.isEmpty) {
      // Sabit yükseklik dar ekranda taşıyordu: en az 200, gerekirse içeriği kadar.
      return [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 200),
          child: ErrorView(error: _mineError!, onRetry: () => _loadMine(reset: true)),
        )
      ];
    }
    if (_mine.isEmpty) {
      return [
        SizedBox(
            height: 160,
            child: EmptyView(icon: LucideIcons.messageCircle, text: context.l10n.supportNoFeedback))
      ];
    }
    return [
      for (final f in _mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BuCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${f['subject'] ?? ''}',
                      style: BuType.bodyStrong.copyWith(color: t.ink)),
                ),
                const SizedBox(width: 8),
                SupportFeedbackPill(f['status'] as String?),
              ]),
              const SizedBox(height: 2),
              Text('${supportFeedbackCategories(context.l10n)[f['category']] ?? context.l10n.supportCatOther} · ${niceDate(f['createdAt'] as String?)}',
                  style: BuType.caption.copyWith(color: t.mut)),
              const SizedBox(height: 6),
              Text('${f['message'] ?? ''}', style: BuType.caption.copyWith(height: 1.4, color: t.ink)),
              if ((f['adminResponse'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text('${f['adminResponse']}', style: BuType.caption.copyWith(height: 1.4, color: t.onSoft)),
                ),
              ],
            ]),
          ),
        ),
      if (_next != null)
        Center(
          child: BuButton(
              label: context.l10n.supportMore, kind: BuButtonKind.outline, compact: true, busy: _more, onPressed: _loadMine),
        ),
    ];
  }
}
