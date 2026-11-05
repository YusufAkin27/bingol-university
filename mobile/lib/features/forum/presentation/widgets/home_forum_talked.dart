import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../home/home_parts.dart' show HomeSectionHeader;
import '../../forum_routes.dart';

/// Ana Sayfa "Kampüste konuşulanlar" kartı: en çok yorumlanan en fazla 3 konu (`sort=MOST_COMMENTED`), kompakt satırlar.
/// Başlığa/"Tümü"ye dokunma forum ana sayfasını, satıra dokunma konuyu açar. Veri yoksa ya da yüklenemezse bölüm
/// TAMAMEN gizlenir ([onUnavailable] ana sayfaya haber verir); yüklenirken ince iskelet görünür.
class HomeForumTalked extends StatefulWidget {
  const HomeForumTalked({super.key, required this.session, this.onUnavailable, this.onLongPressTitle, this.refreshToken, this.api});

  final Session session;
  final VoidCallback? onUnavailable;
  final VoidCallback? onLongPressTitle;

  /// Değişirse (çek-yenile) yeniden yüklenir.
  final Object? refreshToken;
  final ForumApi? api;

  @override
  State<HomeForumTalked> createState() => _HomeForumTalkedState();
}

class _HomeForumTalkedState extends State<HomeForumTalked> {
  late final ForumApi _api = widget.api ?? ForumApi(widget.session);
  List<TopicSummary>? _items;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HomeForumTalked old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load() async {
    final g = ++_gen;
    try {
      final page = await _api.topics(sort: ForumSort.mostCommented, size: 3, force: true);
      if (!mounted || g != _gen) return;
      final items = [for (final t in page.items) if (!t.removed) t].take(3).toList();
      if (items.isEmpty) {
        widget.onUnavailable?.call();
        return;
      }
      setState(() => _items = items);
    } catch (_) {
      // Forum ulaşılamıyorsa ana sayfada hiçbir şey çizilmez (hata kartı yok).
      if (mounted && g == _gen) widget.onUnavailable?.call();
    }
  }

  void _openAll() => openForumHome(context, widget.session);

  Future<void> _openTopic(TopicSummary t) async {
    await openTopicDetail(context, widget.session, t.id, initial: t);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final items = _items;
    return Column(
      key: const ValueKey('homeForumTalked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: BuSpace.pageH,
          child: HomeSectionHeader(
            title: l.forumHomeTalkedTitle,
            action: l.forumHomeTalkedAll,
            accent: true,
            onAction: _openAll,
            onLongPress: widget.onLongPressTitle,
          ),
        ),
        Padding(
          padding: BuSpace.pageH,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.sf,
              borderRadius: BorderRadius.circular(BuRadius.lg),
              border: Border.all(color: t.bd),
            ),
            child: items == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: BuSkeletonScope(
                      child: Column(children: [
                        BuSkeleton.line(height: 14),
                        BuGap.h8,
                        BuSkeleton.line(width: 120, height: 10),
                        BuGap.h20,
                        BuSkeleton.line(height: 14),
                        BuGap.h8,
                        BuSkeleton.line(width: 96, height: 10),
                      ]),
                    ),
                  )
                : Column(children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) Divider(height: 1, thickness: 1, color: t.bdSubtle),
                      _Row(topic: items[i], onTap: () => _openTopic(items[i])),
                    ],
                  ]),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.topic, required this.onTap});

  final TopicSummary topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final cat = topic.category?.name ?? '';
    return Semantics(
      button: true,
      label: '${topic.title}. ${l.forumHomeCommentsA11y('${topic.commentCount}')}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('home-forum-topic-${topic.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(topic.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.3)),
                  BuGap.h4,
                  Row(children: [
                    Icon(BuIcons.messageSquare, size: 14, color: t.mut),
                    BuGap.w4,
                    Text('${topic.commentCount}', style: tt.bodySmall?.copyWith(color: t.mut)),
                    if (cat.isNotEmpty) ...[
                      Text(' · ', style: tt.bodySmall?.copyWith(color: t.mut)),
                      Flexible(child: Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: t.mut))),
                    ],
                  ]),
                ]),
              ),
              Icon(buDirIcon(context, BuIcons.chevronRight), size: 18, color: t.mut),
            ]),
          ),
        ),
      ),
    );
  }
}
