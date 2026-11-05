import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_models.dart';

/// Yatay kategori çipleri: "Tümü" başta, ardından backend'den gelen kategoriler. Seçili çip marka tonunda
/// (kırmızı yalnız seçili durumda). [selectedId] null = Tümü. Kategoriler yüklenirken ince iskelet çipleri çizilir.
class ForumCategoryChips extends StatelessWidget {
  const ForumCategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.loading = false,
  });

  final List<ForumCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Semantics(
      container: true,
      label: l.forumHomeCategories,
      child: SizedBox(
        height: BuSize.touch,
        child: ListView(
          key: const ValueKey('forum-category-chips'),
          scrollDirection: Axis.horizontal,
          padding: BuSpace.pageH,
          children: [
            BuChip(
              key: const ValueKey('forum-chip-all'),
              label: l.forumHomeCategoryAll,
              selected: selectedId == null,
              onTap: () => onSelected(null),
            ),
            if (loading && categories.isEmpty)
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Center(child: BuSkeletonScope(child: BuSkeleton(width: 84, height: 34, radius: 17))),
                ),
            for (final c in categories)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: BuChip(
                  key: ValueKey('forum-chip-${c.id}'),
                  label: c.name,
                  selected: selectedId == c.id,
                  onTap: () => onSelected(c.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
