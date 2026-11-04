import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../posts/social_models.dart';
import 'follow_widgets.dart';

/// Öneri satırı: kişi + (API verirse) öneri nedeni ve sınıf.
class _Suggestion {
  const _Suggestion(this.user, {this.reason, this.classYear});

  final SocialUser user;
  final String? reason;
  final int? classYear;
}

/// "Önerilen kişiler" (`GET /users/me/follow-suggestions`) satırları. Yükleniyor/hata/boş durumlarını kendisi yönetir.
/// [shrink] true iken kaydırılmaz, içeriği kadar yer kaplar (başka listenin içinde).
class FollowSuggestionsList extends StatefulWidget {
  const FollowSuggestionsList({super.key, required this.session, this.shrink = false, this.limit = 20});

  final Session session;
  final bool shrink;
  final int limit;

  @override
  State<FollowSuggestionsList> createState() => _FollowSuggestionsListState();
}

class _FollowSuggestionsListState extends State<FollowSuggestionsList> {
  List<_Suggestion>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await widget.session.api.get('/users/me/follow-suggestions?size=${widget.limit}');
      final list = <_Suggestion>[];
      for (final m in socialItems(r)) {
        final y = m['classYear'] ?? m['grade'];
        final n = y is num ? y.toInt() : int.tryParse('${y ?? ''}');
        final reason = m['reason'];
        list.add(_Suggestion(
          SocialUser.fromJson(m),
          reason: reason is String && reason.trim().isNotEmpty ? reason.trim() : null,
          classYear: n != null && n > 0 && n <= 6 ? n : null,
        ));
      }
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final bottom = widget.shrink ? 8.0 : MediaQuery.paddingOf(context).bottom + 24;
    final pad = EdgeInsets.fromLTRB(20, widget.shrink ? 8 : 12, 20, bottom);

    final Widget child;
    if (_error != null && items == null) {
      child = FollowStatusCard(
        error: true,
        icon: BuIcons.wifiOff,
        title: l.p18FollowErrorTitle,
        message: errorText(_error!),
        onRetry: _load,
      );
    } else if (items == null) {
      child = FollowSkeletonCard(count: widget.shrink ? 2 : 3);
    } else if (items.isEmpty) {
      child = FollowStatusCard(
        icon: BuIcons.userSearch,
        title: l.followSuggestionsEmpty,
        message: l.followFeedHint,
      );
    } else {
      child = FollowCard(children: [
        for (var i = 0; i < items.length; i++)
          BuStaggerItem(
            index: i,
            child: FollowPersonRow(
              session: widget.session,
              user: items[i].user,
              reason: items[i].reason,
              classLabel: items[i].classYear == null ? null : l.p18ClassYear('${items[i].classYear}'),
            ),
          ),
      ]);
    }

    return BuStaggerScope(
      child: widget.shrink
          ? Padding(padding: pad, child: child)
          : SingleChildScrollView(padding: pad, child: child),
    );
  }
}

class FollowSuggestionsPage extends StatelessWidget {
  const FollowSuggestionsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(children: [
        BuHeader(title: context.l10n.followSuggestionsTitle, onBack: () => Navigator.pop(context)),
        Expanded(child: FollowSuggestionsList(session: session)),
      ]),
    );
  }
}
