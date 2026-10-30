import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import '../polls/anket_style.dart';
import '../polls/anket_widgets.dart';
import 'support_common.dart';

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
  late String _category = const ['BUG', 'SUGGESTION', 'COMPLAINT', 'PRAISE'].contains(widget.initialCategory) ? widget.initialCategory : 'BUG';
  bool _busy = false;
  String? _formError;
  int _tab = 0; // 0 form, 1 gonderdiklerim

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
      buHaptic(BuHaptic.light);
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
      supportSnack(context, context.l10n.supportFeedbackThanks, BuToastKind.success);
      setState(() {
        _busy = false;
        _tab = 1;
      });
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
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final label = tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w800);
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Semantics(header: true, child: Text(text, style: label)),
        );
    final types = {
      'BUG': l.supportFbBug,
      'SUGGESTION': l.supportFbSuggestion,
      'COMPLAINT': l.supportFbComplaint,
      'PRAISE': l.supportFbPraise,
    };
    return BuPageScaffold(
      title: l.supportFeedbackTitle,
      large: false,
      onRefresh: () => _loadMine(reset: true),
      bottomInset: 24,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 12),
            child: AnketTabs(labels: [l.supportSend, l.p13FeedbackMine], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
        ),
        if (_tab == 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.profilyardFbIntro, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.5)),
              const SizedBox(height: 12),
              BuCard(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    caption(l.profilyardFbType),
                    SupportCategoryChips(options: types, value: _category, onChanged: (v) => setState(() => _category = v)),
                    caption(l.profilyardFbTitle),
                    SupportField(controller: _subject, hint: l.profilyardFbTitleHint, label: l.profilyardFbTitle, maxLength: 80, soft: true),
                    caption(l.profilyardFbMessage),
                    SupportField(
                      controller: _message,
                      hint: l.profilyardFbMessageHint,
                      label: l.profilyardFbMessage,
                      maxLength: 1000,
                      minLines: 5,
                      maxLines: 8,
                      counter: true,
                      soft: true,
                    ),
                    AnimatedSize(
                      duration: BuMotion.of(context, BuMotion.medium),
                      curve: BuMotion.emphasized,
                      alignment: Alignment.topCenter,
                      child: _formError == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Semantics(
                                liveRegion: true,
                                container: true,
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Padding(padding: const EdgeInsets.only(top: 2), child: Icon(LucideIcons.circleAlert, size: 18, color: t.danger)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_formError!, style: tx.bodyMedium!.copyWith(color: t.danger, height: 1.4))),
                                ]),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    BuButton(label: l.supportSend, icon: LucideIcons.send, busy: _busy, onPressed: _submit),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (_tab == 1) ...[
          SliverToBoxAdapter(child: SupportHeading(l.p13FeedbackMine, padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 10))),
          ..._mineSlivers(),
        ],
      ],
    );
  }

  List<Widget> _mineSlivers() {
    final l = context.l10n;
    final t = context.bu;
    if (_loadingMine) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 0),
            child: BuSkeletonScope(
              child: Column(children: [
                BuSkeleton(height: 112, radius: 20),
                SizedBox(height: 12),
                BuSkeleton(height: 112, radius: 20),
              ]),
            ),
          ),
        ),
      ];
    }
    if (_mineError != null && _mine.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SupportLoadError(
              title: l.p13SuppLoadFailed,
              body: errorText(_mineError!),
              retryLabel: l.supportRetry,
              onRetry: () => _loadMine(reset: true),
            ),
          ),
        ),
      ];
    }
    if (_mine.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SupportEmptyCard(icon: LucideIcons.info, title: l.supportNoFeedback, body: l.p13FeedbackEmptyHint),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.separated(
          itemCount: _mine.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => BuStaggerItem(index: i, child: _FeedbackTile(item: _mine[i])),
        ),
      ),
      if (_next != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            child: Material(
              color: t.sf2,
              borderRadius: BuRadius.bMd,
              child: InkWell(
                borderRadius: BuRadius.bMd,
                onTap: _more ? null : _loadMine,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Center(
                    child: _more
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(l.supportMore, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Icon(LucideIcons.chevronDown, size: 18, color: t.ink),
                          ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// Gönderilen geri bildirim kartı: tür çipi + durum hapı, başlık, tarih; varsa yönetici yanıtı.
class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final resp = item['adminResponse'] as String?;
    final catKey = item['category'] as String?;
    final cat = supportFeedbackCategories(l)[catKey] ?? l.supportCatOther;
    final (catBg, catFg) = switch (catKey) {
      'BUG' => (t.soft, t.onSoft),
      'SUGGESTION' => (t.tint(1).bg, t.tint(1).fg),
      'COMPLAINT' => (cs.errorContainer, t.danger),
      _ => (t.sf2, t.mut),
    };
    final date = niceDate(item['createdAt'] as String?, context: context);
    return BuCard(
      padding: const EdgeInsetsDirectional.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AnketPill(cat, bg: catBg, fg: catFg, small: true),
            const Spacer(),
            SupportFeedbackPill(item['status'] as String?, dark: true),
          ]),
          const SizedBox(height: 12),
          Text('${item['subject'] ?? ''}', style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(LucideIcons.calendar, size: 15, color: t.mut),
            const SizedBox(width: 8),
            Text(date, style: tx.bodySmall!.copyWith(color: t.mut)),
          ]),
          if (resp != null && resp.isNotEmpty) ...[
            const SizedBox(height: 12),
            SupportStaffReply(text: resp),
          ],
        ]),
      ),
    );
  }
}
