import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../posts/social_api.dart';
import '../posts/social_models.dart';
import 'follow_list_page.dart';

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
  List<SocialUser>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await SocialApi(widget.session).followSuggestions(size: widget.limit);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (_error != null && items == null) {
      return widget.shrink
          ? Padding(padding: const EdgeInsets.all(16), child: ErrorView(error: _error!, onRetry: _load))
          : ErrorView(error: _error!, onRetry: _load);
    }
    if (items == null) {
      return Padding(
          padding: const EdgeInsets.all(24), child: Center(child: widget.shrink ? const CircularProgressIndicator() : const LoadingView()));
    }
    if (items.isEmpty) {
      return const EmptyView(icon: LucideIcons.users, text: 'Şimdilik önerilecek kişi yok.');
    }
    return ListView.builder(
      shrinkWrap: widget.shrink,
      physics: widget.shrink ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.shrink ? 8 : MediaQuery.of(context).padding.bottom + 24),
      itemCount: items.length,
      itemBuilder: (_, i) => SocialUserTile(session: widget.session, user: items[i]),
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
        BuHeader(title: 'Önerilen kişiler', onBack: () => Navigator.pop(context)),
        Expanded(child: FollowSuggestionsList(session: session)),
      ]),
    );
  }
}

/// Takip akışı boşken gösterilen açıklama + öneriler.
class FollowingEmptyPanel extends StatelessWidget {
  const FollowingEmptyPanel({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(children: [
            Icon(LucideIcons.users, size: 32, color: t.mut),
            const SizedBox(height: 10),
            Text('Takip ettiklerinin gönderileri burada görünür.',
                textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text('Önerilen kişiler', style: BuType.heading.copyWith(color: t.ink)),
        ),
        FollowSuggestionsList(session: session, shrink: true, limit: 8),
      ],
    );
  }
}
