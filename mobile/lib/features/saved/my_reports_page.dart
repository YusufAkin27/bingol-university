import 'package:flutter/material.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart' show LoadingView;
import 'saved_api.dart';

/// Destek/Gizlilik > "Şikayetlerim": gönderilen şikayetlerin yalnız genel durumu (Açık / Sonuçlandı).
/// Hedef, karar ve moderatör notu sunucudan gelmez. Veri: `GET /reports/mine?cursor=&limit=`.
class MyReportsListPage extends StatefulWidget {
  const MyReportsListPage({super.key, required this.session});

  final Session session;

  @override
  State<MyReportsListPage> createState() => _MyReportsListPageState();
}

class _MyReportsListPageState extends State<MyReportsListPage> {
  late final MyReportsApi _api = MyReportsApi(widget.session);
  final _items = <MyReport>[];
  final _scroll = ScrollController();
  int? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _api.list(cursor: _cursor);
      _items.addAll(p.items);
      _cursor = p.nextCursor;
      _hasMore = p.nextCursor != null;
    } catch (e) {
      _error = e;
      _hasMore = false;
    }
    if (mounted) setState(() => _loading = false);
  }

  String _typeLabel(String type) {
    final l = context.l10n;
    return switch (type) {
      'USER' => l.reportsTypeUser,
      'MESSAGE' => l.reportsTypeMessage,
      'POST' => l.reportsTypePost,
      'COMMUNITY' => l.reportsTypeCommunity,
      'EVENT' => l.reportsTypeEvent,
      'FORUM_TOPIC' => l.reportsTypeTopic,
      'FORUM_COMMENT' => l.reportsTypeComment,
      _ => l.reportsTypeOther,
    };
  }

  String _reasonLabel(String reason) {
    final l = context.l10n;
    return switch (reason) {
      'SPAM' => l.reportReasonSpam,
      'HARASSMENT' => l.reportReasonHarassment,
      'INAPPROPRIATE' => l.reportReasonInappropriate,
      'IMPERSONATION' => l.reportReasonImpersonation,
      'PERSONAL_INFO' => l.reportsReasonPersonalInfo,
      _ => l.reportReasonOther,
    };
  }

  String _date(DateTime? d) => d == null ? '' : MaterialLocalizations.of(context).formatMediumDate(d);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_items.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_items.isEmpty && _error != null) {
      body = BuErrorState(error: _error!, onRetry: () {
        setState(() => _hasMore = true);
        _reload();
      });
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_reload),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: BuEmptyState(
                key: const ValueKey('reports-empty'),
                icon: BuIcons.flag,
                title: l.reportsEmptyTitle,
                message: l.reportsEmptyBody,
              ),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: Analytics.pullRefresh(_reload),
        child: ListView.builder(
          key: const ValueKey('reports-list'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 24),
          itemCount: _items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.reportsMineNote, style: tx.bodyMedium!.copyWith(fontSize: 13, height: 1.5, color: t.mut)),
              );
            }
            if (i == _items.length + 1) return _footer();
            return _ReportRow(
              report: _items[i - 1],
              title: _typeLabel(_items[i - 1].targetType),
              reason: _reasonLabel(_items[i - 1].reason),
              date: _items[i - 1].resolved && _items[i - 1].resolvedAt != null ? l.reportsResolvedOn(_date(_items[i - 1].resolvedAt)) : _date(_items[i - 1].createdAt),
              statusLabel: _items[i - 1].resolved ? l.reportsStatusResolved : l.reportsStatusOpen,
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: l.reportsMineTitle, visibleTitle: true, onBack: () => Navigator.maybePop(context)),
        Expanded(child: body),
      ]),
    );
  }

  Widget _footer() {
    final l = context.l10n;
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: BuButton(
            key: const ValueKey('reports-footer-retry'),
            label: l.commonRetry,
            compact: true,
            kind: BuButtonKind.outline,
            onPressed: () {
              setState(() => _hasMore = true);
              _loadMore();
            },
          ),
        ),
      );
    }
    if (_hasMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return const SizedBox(height: 4);
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report, required this.title, required this.reason, required this.date, required this.statusLabel});

  final MyReport report;
  final String title;
  final String reason;
  final String date;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final sub = [reason, if (date.isNotEmpty) date].join(' · ');
    return Semantics(
      container: true,
      label: '$title. $sub. $statusLabel',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('report-${report.id}'),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(fontSize: 16, color: t.ink)),
              const SizedBox(height: 2),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 13, color: t.mut)),
            ]),
          ),
          const SizedBox(width: 12),
          // Nötr rozet + simge (renge dayanmaz): açık = saat, sonuçlandı = onay.
          Container(
            key: ValueKey('report-status-${report.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.bd)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(report.resolved ? BuIcons.check : BuIcons.clock, size: 14, color: t.mut),
              const SizedBox(width: 6),
              Text(statusLabel, style: tx.bodyMedium!.copyWith(fontSize: 13, color: t.ink)),
            ]),
          ),
        ]),
      ),
    );
  }
}
