import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show niceDate;
import '../polls/anket_flat.dart';
import '../polls/anket_style.dart' show AnketPill;
import 'support_common.dart';
import 'support_feedback_page.dart';
import 'support_list_widgets.dart';
import 'support_new_ticket_page.dart';
import 'support_suggestions_page.dart';
import 'support_ticket_page.dart';

/// Destek: "Sık sorulan sorular" akordeonu, "Taleplerim" (açık talep sayacı + talep kartları; sınırda "Yeni talep"
/// yerine açıklama) ve altta "Geri bildirim · Öneri panosu" metin bağlantıları.
class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.session});

  final Session session;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  /// Bu sayıdan çok soru varsa arama + kategori süzgeci görünür (referansta üç soru: süzgeç yok).
  static const _filterThreshold = 6;

  List<Map<String, dynamic>> _faq = [];
  final List<Map<String, dynamic>> _tickets = [];
  int? _next;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  String? _ticketsError;
  bool _rateLimited = false;
  int? _openCount; // sunucu `openCount` (yoksa yüklenen taleplerden türetilir)
  int _maxOpen = kSupportDefaultMaxOpen;
  Map<int, String> _seen = {};
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
      _openCount = (r['openCount'] as num?)?.toInt();
      _maxOpen = (r['maxOpen'] as num?)?.toInt() ?? kSupportDefaultMaxOpen;
    } catch (e) {
      if (!mounted) return;
      tErr = supportError(context, e);
      limited = e is ApiError && e.status == 429;
    }
    _seen = await SupportSeenStore.load();
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
    if (changed == true) {
      _load();
    } else {
      // Talep açıldıysa "Yeni yanıt" vurgusu kalkar (görülenler cihazda tutulur).
      final seen = await SupportSeenStore.load();
      if (mounted) setState(() => _seen = seen);
    }
  }

  /// Açık talep sayısı: sunucudan; eski sunucuda tüm talepler yüklendiyse kapalı olmayanları saymak.
  int? get _openNow {
    if (_openCount != null) return _openCount;
    if (_next != null || _tickets.isEmpty) return null;
    return _tickets.where((t) => t['status'] != 'CLOSED').length;
  }

  bool get _limitReached => (_openNow ?? 0) >= _maxOpen;

  List<String> get _categories => [
        for (final g in _faq)
          if (((g['category'] as String?) ?? '').isNotEmpty) g['category'] as String,
      ];

  int get _faqCount => _faq.fold(0, (n, g) => n + (((g['items'] as List?) ?? []).length));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final state = _loading ? BuViewState.loading : (_error != null ? BuViewState.error : BuViewState.ready);
    final cats = _categories;
    final filters = _faqCount > _filterThreshold;
    void newTicket() => _push(NewTicketPage(session: widget.session));
    final noTickets = _tickets.isEmpty && _ticketsError == null;
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
      bottomInset: 28,
      slivers: [
        if (_rateLimited)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 8, kAnketPad, 0),
              child: AnketAmberNote(l.supportTooManyRequests),
            ),
          ),
        SliverToBoxAdapter(child: _SectionTitle(l.p13SuppFaqHeading, top: 24, icon: BuIcons.info)),
        if (filters)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.ink),
                decoration: anketFieldDeco(context, hint: l.destekFaqSearchHint),
              ),
            ),
          ),
        if (filters && cats.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: AnketTextTabs(
                labels: [l.destekFaqAll, ...cats],
                index: _cat == null ? 0 : cats.indexOf(_cat!) + 1,
                onChanged: (i) => setState(() => _cat = i == 0 ? null : cats[i - 1]),
              ),
            ),
          ),
        SliverToBoxAdapter(child: _faqList()),
        SliverToBoxAdapter(child: _SectionTitle(l.p13TicketsHeading, top: 25, icon: BuIcons.messageCircle)),
        if (_openNow != null && (_tickets.isNotEmpty || _openNow! > 0))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 14),
              child: SupportOpenMeter(open: _openNow!, max: _maxOpen),
            ),
          ),
        ..._ticketSlivers(newTicket),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 24, kAnketPad, 0),
            child: Column(children: [
              if (!noTickets && _limitReached) SupportLimitNote(max: _maxOpen),
              if (!noTickets && !_limitReached) BuButton(label: l.supportNewTicketTitle, icon: BuIcons.plus, onPressed: newTicket),
              Padding(
                padding: EdgeInsets.only(top: noTickets ? 0 : 6),
                child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  _LinkText(
                    label: l.supportFeedbackTitle,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeedbackPage(session: widget.session))),
                  ),
                  ExcludeSemantics(
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.mut)))),
                  _LinkText(
                    label: l.supportBoard,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SuggestionsPage(session: widget.session))),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _faqList() {
    final l = context.l10n;
    final rows = <Widget>[];
    var idx = 0;
    for (final g in _faq) {
      final cat = g['category'] as String?;
      if (_cat != null && cat != _cat) continue;
      final items = ((g['items'] as List?) ?? [])
          .whereType<Map>()
          .where((it) => _q.isEmpty || '${it['question'] ?? ''}'.toLowerCase().contains(_q) || '${it['answer'] ?? ''}'.toLowerCase().contains(_q))
          .toList();
      for (final it in items) {
        final i = idx++;
        rows.add(_FaqTile(
          question: '${it['question'] ?? ''}',
          answer: '${it['answer'] ?? ''}',
          open: _open.contains(i),
          onTap: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
        ));
      }
    }
    if (rows.isEmpty) {
      return AnketStateLine(
          text: _faq.isNotEmpty ? l.destekFaqNoMatch : l.supportNoFaq, padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 4, kAnketPad, 0));
    }
    return Column(children: rows);
  }

  List<Widget> _ticketSlivers(VoidCallback newTicket) {
    final l = context.l10n;
    if (_ticketsError != null && _tickets.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: AnketStateLine(
            text: l.pollLoadFailedRetry,
            actionLabel: l.supportRetry,
            onAction: _load,
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
          ),
        ),
      ];
    }
    if (_tickets.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 0),
            child: _EmptyTickets(onNew: newTicket),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: Column(children: [
          for (var i = 0; i < _tickets.length; i++)
            _TicketTile(
              ticket: _tickets[i],
              unread: supportTicketUnread(_tickets[i], _seen),
              onTap: () => _push(SupportTicketPage(session: widget.session, ticketId: (_tickets[i]['id'] as num).toInt())),
            ),
          if (_more) const BuSkeletonScope(child: AnketSkeletonRow()),
        ]),
      ),
    ];
  }
}

/// Talep yokken: simgeli açıklama kartı + "Yeni talep" düğmesi.
class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd), boxShadow: BuElevation.of(context, 1)),
      child: Column(children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(18)),
            child: Icon(BuIcons.messageCircle, size: 26, color: t.onSoft),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(l.p68NoTickets, textAlign: TextAlign.center, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        Text(l.supEmptyBody, textAlign: TextAlign.center, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
        const SizedBox(height: 14),
        BuButton(label: l.supportNewTicketTitle, icon: BuIcons.plus, kind: BuButtonKind.soft, onPressed: onNew),
      ]),
    );
  }
}

/// Bölüm başlığı (Stitch v3): 18 sp/600 ink; tek satır, sığmazsa küçülür.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.top, this.icon = BuIcons.info});

  final String text;
  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, top, kAnketPad, 12),
        child: Row(children: [
          BuFeatureIcon(icon: icon, size: 32),
          const SizedBox(width: 10),
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(text,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(color: context.bu.ink, fontSize: 17, fontWeight: FontWeight.w600)))),
        ]),
      );
}

/// Alt bağlantı: muted 14 sp metin (48 dp dokunma alanı).
class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        style: TextButton.styleFrom(foregroundColor: context.bu.mut, minimumSize: const Size(48, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: onTap,
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: context.bu.mut, fontWeight: FontWeight.w400)),
      );
}

/// SSS satırı: kartsız; soru 16 sp/500 + sağda chevron (açıkken yukarı), cevap 14 sp muted; alt `bd` ayraç.
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
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 8),
      decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.bd), boxShadow: BuElevation.of(context, 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            onTap: () {
              buHaptic(BuHaptic.selection);
              onTap();
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: open ? 0 : 56),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, open ? 17 : 12, 16, open ? 10 : 12),
                child: Row(children: [
                  Expanded(child: Text(question, style: tx.titleMedium!.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w500, height: 1.35))),
                  const SizedBox(width: 12),
                  // Ok tek simge: açılınca 180 derece döner (yalnız transform).
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: d,
                    curve: BuMotion.emphasized,
                    child: Icon(BuIcons.chevronDown, size: 20, color: t.mut),
                  ),
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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 17),
                  // Cevap açılırken solarak belirir (açılışta bir kez).
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: d,
                    curve: BuMotion.standard,
                    builder: (_, v, child) => Opacity(opacity: v, child: child),
                    child: Text(answer, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }
}

/// Talep kartı: kategori karosu, konu (okunmamış yanıtta kalın + "Yeni yanıt" rozeti), son mesaj önizlemesi
/// (sunucu `lastMessage` verirse; yoksa kategori adı), altta durum hapı + tarih ve sağda ok.
/// Yeni yanıtlı kart marka zeminli ve `pr` çerçevelidir.
class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap, this.unread = false});

  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  final bool unread;

  /// Aynı yıl: "12 Ekim"; değilse "12 Ekim 2025".
  static String dateLabel(BuildContext context, String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return d == null ? niceDate(iso, context: context) : anketDayLabel(context, d);
  }

  /// "Destek: ..." / "Sen: ..." / "Ek gönderildi"; sunucu `lastMessage` vermezse null.
  static String? previewOf(BuildContext context, Map<String, dynamic> ticket) {
    final lm = ticket['lastMessage'];
    if (lm is! Map) return null;
    final l = context.l10n;
    final text = '${lm['text'] ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasAtt = ((lm['attachmentCount'] as num?)?.toInt() ?? 0) > 0 || lm['hasAttachments'] == true;
    final body = text.isNotEmpty ? text : (hasAtt ? l.supAttachmentSent : '');
    if (body.isEmpty) return null;
    return lm['fromStaff'] == true ? l.supLastStaff(body) : l.supLastYou(body);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final status = ticket['status'] as String?;
    final st = supportTicketStatusStyle(context, status);
    final date = dateLabel(context, ticket['createdAt'] as String?);
    final cat = ticket['category'] as String?;
    final catLabel = supportTicketCategories(l)[cat];
    final preview = previewOf(context, ticket);
    final subject = '${ticket['subject'] ?? ''}';
    final second = preview ?? catLabel;
    return Semantics(
      button: true,
      label: '$subject, ${st.label}, $date${unread ? ', ${l.supNewReply}' : ''}',
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(kAnketPad, 0, kAnketPad, 10),
        decoration: BoxDecoration(
          color: unread ? t.soft : t.sf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: unread ? t.selectedBorder : t.bd, width: unread ? 1.5 : 1),
          boxShadow: BuElevation.of(context, 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('supTicket${ticket['id']}'),
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              buHaptic(BuHaptic.selection);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: unread ? t.sf : t.soft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(supportTicketCategoryIcons[cat] ?? BuIcons.messageCircle, size: 22, color: t.onSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.titleMedium!.copyWith(color: t.ink, fontSize: 16, fontWeight: unread ? FontWeight.w800 : FontWeight.w700, height: 1.3)),
                    if (second != null && second.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(second, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: unread ? t.ink : t.mut, height: 1.35)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (unread)
                        AnketPill(l.supNewReply, bg: t.pr, fg: t.onPr, small: true)
                      else
                        AnketPill(st.label, bg: st.bg, fg: st.fg, icon: st.icon, small: true),
                      Text(date, maxLines: 1, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.2)),
                    ]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 12),
                  child: ExcludeSemantics(child: Icon(BuIcons.chevronRight, size: 20, color: t.mut)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}


/// İlk yükleme iskeleti: iki bölüm başlığı + satırlar.
class _SupportSkeleton extends StatelessWidget {
  const _SupportSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: context.l10n.commonLoading,
        liveRegion: true,
        container: true,
        child: const BuSkeletonScope(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 28, kAnketPad, 14), child: BuSkeleton.line(width: 170, height: 18)),
            AnketSkeletonRow(titleWidth: 250),
            AnketSkeletonRow(titleWidth: 200),
            AnketSkeletonRow(titleWidth: 230),
            Padding(padding: EdgeInsetsDirectional.fromSTEB(kAnketPad, 28, kAnketPad, 14), child: BuSkeleton.line(width: 110, height: 18)),
            AnketSkeletonRow(titleWidth: 240),
            AnketSkeletonRow(titleWidth: 190),
          ]),
        ),
      );
}
