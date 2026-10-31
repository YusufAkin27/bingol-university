import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_gate.dart' show appVersion;
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import '../polls/anket_widgets.dart';
import 'support_common.dart';
import 'support_feedback_page.dart';
import 'support_new_ticket_page.dart';
import 'support_suggestions_page.dart';
import 'support_ticket_page.dart';

/// Destek: SSS akordeonu, talep oluşturma, taleplerim, geri bildirim ve öneri panosu.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.session});

  final Session session;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  List<Map<String, dynamic>> _faq = [];
  final List<Map<String, dynamic>> _tickets = [];
  int? _next;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  String? _ticketsError;
  bool _rateLimited = false;
  final Set<int> _open = {};
  final _search = TextEditingController();
  String _q = '';
  String? _cat; // seçili SSS kategorisi (null = tümü)
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = widget.session.api;
    Object? faqErr;
    try {
      final r = await api.get('/faq');
      _faq = (r as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (e) {
      faqErr = e;
    }
    String? tErr;
    var limited = false;
    try {
      final r = await api.get('/support/tickets?size=10') as Map<String, dynamic>;
      _tickets
        ..clear()
        ..addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
      _next = (r['nextCursor'] as num?)?.toInt();
    } catch (e) {
      if (!mounted) return;
      tErr = supportError(context, e);
      limited = e is ApiError && e.status == 429;
    }
    if (!mounted) return;
    setState(() {
      // Her iki istek de başarısızsa tam ekran hata göster.
      _error = (faqErr != null && tErr != null) ? faqErr : null;
      _ticketsError = tErr;
      _rateLimited = limited;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_next == null || _more) return;
    setState(() => _more = true);
    try {
      final r = await widget.session.api.get('/support/tickets?size=10&cursor=$_next') as Map<String, dynamic>;
      _tickets.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
      _next = (r['nextCursor'] as num?)?.toInt();
    } catch (e) {
      if (mounted) supportSnack(context, supportError(context, e), BuToastKind.error);
    }
    if (mounted) setState(() => _more = false);
  }

  Future<void> _push(Widget page) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (changed == true) _load();
  }

  List<String> get _categories => [
        for (final g in _faq)
          if (((g['category'] as String?) ?? '').isNotEmpty) g['category'] as String,
      ];

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = _loading ? BuViewState.loading : (_error != null ? BuViewState.error : BuViewState.ready);
    final cats = _categories;
    return BuPageScaffold(
      title: l.supportTitle,
      large: false,
      state: state,
      error: _error,
      onRetry: () {
        setState(() => _loading = true);
        _load();
      },
      onRefresh: _load,
      controller: _scroll,
      loading: const _SupportSkeleton(),
      slivers: [
        if (_rateLimited)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
              child: SupportNote(icon: LucideIcons.triangleAlert, text: l.supportTooManyRequests),
            ),
          ),
        SliverToBoxAdapter(child: SupportHeading(l.p13SuppFaqHeading)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BuSearchField(
              hint: l.destekFaqSearchHint,
              controller: _search,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
        ),
        if (cats.length > 1)
          SliverToBoxAdapter(
            child: _FaqChips(
              labels: [l.destekFaqAll, ...cats],
              selected: _cat == null ? 0 : cats.indexOf(_cat!) + 1,
              onSelected: (i) => setState(() => _cat = i == 0 ? null : cats[i - 1]),
            ),
          ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: _faqCard())),
        SliverToBoxAdapter(child: SupportHeading(l.p13TicketsHeading)),
        ..._ticketSlivers(),
        SliverToBoxAdapter(child: SupportHeading(l.p13ShareHeading)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BuCard(
              padding: const EdgeInsetsDirectional.all(12),
              child: Column(children: [
                _ShareRow(
                  icon: Icons.star_rounded,
                  bg: context.bu.soft,
                  fg: context.bu.pr,
                  title: l.supportFeedbackTitle,
                  subtitle: l.p13SuppFeedbackSub,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session))),
                ),
                const SizedBox(height: 8),
                _ShareRow(
                  icon: LucideIcons.lightbulb,
                  bg: context.bu.tint(1).bg,
                  fg: context.bu.tint(1).fg,
                  title: l.supportBoard,
                  subtitle: l.p13SuppBoardSub,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsPage(session: widget.session))),
                ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: Center(
              child: Text(l.profileVersion(appVersion),
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(color: context.bu.mut, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _faqCard() {
    final l = context.l10n;
    final rows = <Widget>[];
    var idx = 0;
    for (final g in _faq) {
      final cat = g['category'] as String?;
      if (_cat != null && cat != _cat) continue;
      final items = ((g['items'] as List?) ?? [])
          .whereType<Map>()
          .where((it) =>
              _q.isEmpty ||
              '${it['question'] ?? ''}'.toLowerCase().contains(_q) ||
              '${it['answer'] ?? ''}'.toLowerCase().contains(_q))
          .toList();
      for (final it in items) {
        final i = idx++;
        rows.add(Padding(
          padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 8),
          child: _FaqTile(
            question: '${it['question'] ?? ''}',
            answer: '${it['answer'] ?? ''}',
            open: _open.contains(i),
            onTap: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
          ),
        ));
      }
    }
    if (rows.isEmpty) {
      final filtered = _faq.isNotEmpty;
      return SupportEmptyCard(
        icon: filtered ? LucideIcons.searchX : LucideIcons.circleQuestionMark,
        title: filtered ? l.destekFaqNoMatch : l.supportNoFaq,
        body: filtered ? l.p13SuppFaqNoMatchBody : l.p13SuppFaqEmptyBody,
      );
    }
    return BuCard(padding: const EdgeInsetsDirectional.all(12), child: Column(children: rows));
  }

  List<Widget> _ticketSlivers() {
    final l = context.l10n;
    final create = BuButton(
      label: l.supportCreateTicket,
      icon: LucideIcons.circlePlus,
      onPressed: () => _push(NewTicketPage(session: widget.session)),
    );
    if (_ticketsError != null && _tickets.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              SupportLoadError(title: l.p13SuppLoadFailed, body: _ticketsError!, retryLabel: l.supportRetry, onRetry: _load),
              const SizedBox(height: 12),
              create,
            ]),
          ),
        ),
      ];
    }
    if (_tickets.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              SupportEmptyCard(icon: LucideIcons.mail, title: l.supportNoTickets, body: l.p13SuppTicketsEmptyBody),
              const SizedBox(height: 12),
              create,
            ]),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BuCard(
            padding: const EdgeInsetsDirectional.all(12),
            child: Column(children: [
              for (var i = 0; i < _tickets.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TicketTile(
                    ticket: _tickets[i],
                    onTap: () => _push(SupportTicketPage(session: widget.session, ticketId: (_tickets[i]['id'] as num).toInt())),
                  ),
                ),
              if (_more) const BuSkeletonScope(child: BuSkeleton(height: 64, radius: 16)),
              if (_more) const SizedBox(height: 8),
              create,
            ]),
          ),
        ),
      ),
    ];
  }
}

/// SSS kategori çipleri: seçili koyu (ink) dolgu, diğerleri beyaz; yatay kayar.
class _FaqChips extends StatelessWidget {
  const _FaqChips({required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Semantics(
            button: true,
            selected: i == selected,
            label: labels[i],
            excludeSemantics: true,
            onTap: () => onSelected(i),
            child: Material(
              color: i == selected ? t.soft : t.sf,
              shape: StadiumBorder(side: BorderSide(color: i == selected ? t.selectedBorder : t.bd)),
              child: InkWell(
                borderRadius: BuRadius.bPill,
                onTap: () {
                  if (i != selected) buHaptic(BuHaptic.selection);
                  onSelected(i);
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 18),
                    child: Center(
                      widthFactor: 1,
                      child: Text(labels[i], style: tx.labelLarge!.copyWith(color: i == selected ? t.onSoft : t.ink, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// SSS satırı: gri yuvarlak kutu; soru + ok, cevap yumuşakça açılır.
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer, required this.open, required this.onTap});

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final d = BuMotion.of(context, BuMotion.medium);
    return AnimatedContainer(
      duration: d,
      curve: BuMotion.standard,
      decoration: BoxDecoration(color: open ? Color.alphaBlend(t.ink.withValues(alpha: .04), t.sf2) : t.sf2, borderRadius: BuRadius.bMd),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            borderRadius: BuRadius.bMd,
            onTap: () {
              buHaptic(BuHaptic.selection);
              onTap();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
                child: Row(children: [
                  Expanded(child: Text(question, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.35))),
                  const SizedBox(width: 12),
                  Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 20, color: open ? t.pr : t.mut),
                ]),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: d,
          curve: BuMotion.emphasized,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                  child: Text(answer, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.55)),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

/// Talep satırı: durum noktası, konu, durum hapı; altta tarih.
class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final Map<String, dynamic> ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final status = ticket['status'] as String?;
    final date = niceDate(ticket['createdAt'] as String?, context: context);
    return Semantics(
      button: true,
      label: '${ticket['subject'] ?? ''}, ${supportTicketStatusStyle(context, status).label}, $date',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.sf2,
        borderRadius: BuRadius.bMd,
        child: InkWell(
          borderRadius: BuRadius.bMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: supportStatusDotColor(context, status), shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${ticket['subject'] ?? ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800, height: 1.3)),
                ),
                const SizedBox(width: 8),
                SupportStatusPill(status),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(LucideIcons.calendar, size: 15, color: t.mut),
                const SizedBox(width: 8),
                Text(date, style: tx.bodySmall!.copyWith(color: t.mut)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Paylaşım satırı (geri bildirim / öneri panosu): yuvarlak simge, başlık, açıklama, ok.
class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.icon, required this.bg, required this.fg, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: t.sf2,
        borderRadius: BuRadius.bMd,
        child: InkWell(
          borderRadius: BuRadius.bMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 14, 12),
            child: Row(children: [
              AnketRoundIcon(icon, size: 48, bg: bg, fg: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// İlk yükleme iskeleti: arama, çipler, sorular, talepler.
class _SupportSkeleton extends StatelessWidget {
  const _SupportSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              BuSkeleton.line(width: 160, height: 16),
              SizedBox(height: 12),
              BuSkeleton(height: 52, radius: 26),
              SizedBox(height: 12),
              BuSkeleton(height: 44, radius: 22),
              SizedBox(height: 12),
              BuSkeleton(height: 56, radius: 16),
              SizedBox(height: 8),
              BuSkeleton(height: 56, radius: 16),
              SizedBox(height: 8),
              BuSkeleton(height: 56, radius: 16),
              SizedBox(height: 24),
              BuSkeleton.line(width: 120, height: 16),
              SizedBox(height: 12),
              BuSkeleton(height: 64, radius: 16),
              SizedBox(height: 8),
              BuSkeleton(height: 64, radius: 16),
            ]),
          ),
        ),
      );
}
