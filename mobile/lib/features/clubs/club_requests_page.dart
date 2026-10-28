import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'kulup_widgets.dart';

/// Kulübe gelen katılma istekleri: avatar + ad + cevaplar, Onayla / Reddet.
/// Pop sonucu: en az bir istek karara bağlandıysa true (kulüp sayfası sayıları yeniler).
class ClubRequestsPage extends StatefulWidget {
  const ClubRequestsPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<ClubRequestsPage> createState() => _ClubRequestsPageState();
}

class _ClubRequestsPageState extends State<ClubRequestsPage> {
  final _items = <Map<String, dynamic>>[];
  int? _next;
  bool _loading = true;
  Object? _error;
  bool _changed = false;
  final _busy = <int>{};
  int _gen = 0;

  String get _base => '/communities/${widget.communityId}';

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final gen = ++_gen;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final cursor = (!reset && _next != null) ? '&cursor=$_next' : '';
      final r = await widget.session.api.get('$_base/requests?include=answers&size=20$cursor') as Map;
      if (!mounted || gen != _gen) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll((r['items'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
        _next = (r['nextCursor'] as num?)?.toInt();
        _loading = false;
      });
    } catch (e) {
      if (mounted && gen == _gen) setState(() { _error = e; _loading = false; });
    }
  }

  Future<void> _decide(Map<String, dynamic> r, bool approve) async {
    final uid = (r['userId'] as num).toInt();
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      await widget.session.api.post('$_base/requests/$uid/${approve ? 'approve' : 'reject'}');
      if (!mounted) return;
      setState(() {
        _items.remove(r);
        _changed = true;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_loading && _items.isEmpty) {
      body = const LoadingView();
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: () => _load(reset: true));
    } else if (_items.isEmpty) {
      body = EmptyView(icon: LucideIcons.inbox, text: context.l10n.clubMgmtNoPending);
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length + (_next != null ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i >= _items.length) {
              return Center(
                child: TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: Text(context.l10n.clubMgmtMoreRequests),
                ),
              );
            }
            return _row(t, _items[i]);
          },
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            BuHeader(
              title: context.l10n.kulupdetayRequestsTitle,
              subtitle: _items.isEmpty ? null : context.l10n.clubMgmtWaitingCount('${_items.length}${_next != null ? '+' : ''}'),
              onBack: () => Navigator.pop(context, _changed),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _row(BuTokens t, Map<String, dynamic> r) {
    final uid = (r['userId'] as num).toInt();
    final busy = _busy.contains(uid);
    final answers = (r['answers'] as List?)?.whereType<Map>().toList() ?? const [];
    return BuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KulupAvatar(name: r['displayName']?.toString(), url: r['avatarUrl']?.toString(), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text((r['displayName'] ?? context.l10n.clubMgmtUser).toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(fontWeight: FontWeight.w700, color: t.ink)),
              ),
            ],
          ),
          if (answers.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in answers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((a['question'] ?? '').toString(), style: BuType.label.copyWith(color: t.mut)),
                          const SizedBox(height: 2),
                          Text((a['answer'] ?? '').toString(), style: BuType.body.copyWith(height: 1.4, color: t.ink)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: KulupActionButton(
                    label: context.l10n.clubMgmtReject, onPressed: busy ? null : () => _decide(r, false)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: KulupActionButton(
                    primary: true,
                    label: busy ? context.l10n.kulupdetayApproving : context.l10n.clubMgmtApprove,
                    onPressed: busy ? null : () => _decide(r, true)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
