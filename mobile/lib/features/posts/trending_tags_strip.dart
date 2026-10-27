import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
import 'hashtag_posts_page.dart';
import 'social_api.dart';
import 'social_models.dart';

/// Keşfet'te trend etiketler şeridi (`GET /hashtags/trending`). Boşsa ya da hata olursa hiç yer kaplamaz.
class TrendingTagsStrip extends StatefulWidget {
  const TrendingTagsStrip({super.key, required this.session});

  final Session session;

  @override
  State<TrendingTagsStrip> createState() => _TrendingTagsStripState();
}

class _TrendingTagsStripState extends State<TrendingTagsStrip> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<TrendingTag> _tags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await SocialApi(widget.session).trending();
      if (mounted) setState(() => _tags = r.where((e) => e.tag.isNotEmpty).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_tags.isEmpty) return const SizedBox.shrink();
    final t = context.bu;
    return SizedBox(
      key: const ValueKey('trendingTags'),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = _tags[i];
          return Center(
            child: Semantics(
              button: true,
              label: 'Etiket ${g.tag}${g.postCount > 0 ? ', ${g.postCount} gönderi' : ''}',
              excludeSemantics: true,
              child: Material(
                color: t.soft,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => openHashtagPosts(context, widget.session, g.tag),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.trendingUp, size: 14, color: t.onSoft),
                      const SizedBox(width: 6),
                      Text('#${g.tag}', style: BuType.label.copyWith(color: t.onSoft)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
