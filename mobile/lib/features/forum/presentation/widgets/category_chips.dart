import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_category_filter.dart';
import '../../data/forum_models.dart';

/// Yatay kategori çipleri: "Tümü" başta, ardından en çok ilk [kForumChipLimit] kategori (sunucu sırası); seçili kategori
/// bunların dışındaysa (seçiciden seçildi) hemen "Tümü"den sonra görünür. Kategori sayısı sınırı aşıyorsa sonda
/// "Tüm kategoriler" çipi (sağda, kaydırmadan bağımsız sabit) çıkar ve [onOpenAll] ile aramalı seçiciyi açar. Seçili çip marka tonunda.
/// [selectedId] null = Tümü. Kategoriler yüklenirken ince iskelet çipleri çizilir.
class ForumCategoryChips extends StatelessWidget {
  const ForumCategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.onOpenAll,
    this.loading = false,
    this.listKey = const ValueKey('forum-category-chips'),
  });

  final List<ForumCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  /// "Tüm kategoriler" çipine dokunuşu; null ise çip hiç gösterilmez.
  final VoidCallback? onOpenAll;
  final bool loading;

  /// Kaydırılan satırın anahtarı (arama sayfası kendi anahtarını verir).
  final Key listKey;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final shown = forumChipCategories(categories, selectedId);
    final hasMore = onOpenAll != null && categories.length > kForumChipLimit;
    // "Tüm kategoriler" kaydırılan satırın DIŞINDA, sağda sabit durur: kaydırmadan hep görünür (aramalı seçiciye
    // ulaşmak kategori sayısına bağlı olmasın). Dar ekran / büyük yazıda yalnız simge (etiket erişilebilirlik adıdır).
    return Semantics(
      container: true,
      label: l.forumHomeCategories,
      child: SizedBox(
        height: BuSize.touch,
        child: LayoutBuilder(builder: (context, box) {
          final compact = box.maxWidth < 380 || MediaQuery.textScalerOf(context).scale(14) > 16.5;
          return Row(children: [
            Expanded(
              child: ListView(
                key: listKey,
                scrollDirection: Axis.horizontal,
                padding: BuSpace.pageH.copyWith(end: hasMore ? 4 : null),
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
                  for (final c in shown)
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
            if (hasMore)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: BuSpace.page),
                child: compact
                    ? BuIconButton(
                        key: const ValueKey('forum-chip-more'),
                        icon: BuIcons.layers,
                        tooltip: l.forumCatAll,
                        onTap: onOpenAll,
                      )
                    : BuChip(
                        key: const ValueKey('forum-chip-more'),
                        label: l.forumCatAll,
                        icon: BuIcons.layers,
                        onTap: onOpenAll,
                      ),
              ),
          ]);
        }),
      ),
    );
  }
}
