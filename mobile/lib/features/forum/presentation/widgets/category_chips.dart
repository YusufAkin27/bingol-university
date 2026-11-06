import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../widgets/bu.dart';
import '../../data/forum_category_filter.dart';
import '../../data/forum_models.dart';

/// Yatay kategori çipleri: "Tümü" başta, ardından BÜTÜN kategoriler (grup sırasıyla) tek bir yatay kaydırılan satırda.
/// Satır mantıksal başlangıçtan (RTL'de sağdan) başlar; seçili çip görünür alana kayar. Çipler `Row` içinde
/// normal akışta durur (sabit konumlu öğe yok), bu yüzden üst üste binmez. [selectedId] null = Tümü.
class ForumCategoryChips extends StatefulWidget {
  const ForumCategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    this.loading = false,
    this.listKey = const ValueKey('forum-category-chips'),
  });

  final List<ForumCategory> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  final bool loading;

  /// Kaydırılan satırın anahtarı (arama sayfası kendi anahtarını verir).
  final Key listKey;

  @override
  State<ForumCategoryChips> createState() => _ForumCategoryChipsState();
}

class _ForumCategoryChipsState extends State<ForumCategoryChips> {
  final _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(ForumCategoryChips old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _selectedKey.currentContext;
      if (!mounted || c == null) return;
      Scrollable.ensureVisible(c,
          alignment: .5, duration: BuMotion.of(context, BuMotion.medium), curve: BuMotion.emphasizedDecelerate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = forumChipsAll(widget.categories);
    final sel = widget.selectedId;
    return Semantics(
      container: true,
      label: l.forumHomeCategories,
      child: SizedBox(
        height: BuSize.touch,
        child: SingleChildScrollView(
          key: widget.listKey,
          scrollDirection: Axis.horizontal,
          padding: BuSpace.pageH,
          child: Row(children: [
            KeyedSubtree(
              key: sel == null ? _selectedKey : null,
              child: BuChip(
                key: const ValueKey('forum-chip-all'),
                label: l.forumHomeCategoryAll,
                selected: sel == null,
                onTap: () => widget.onSelected(null),
              ),
            ),
            if (widget.loading && all.isEmpty)
              for (var i = 0; i < 4; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: 8),
                  child: Center(child: BuSkeletonScope(child: BuSkeleton(width: 84, height: 34, radius: 17))),
                ),
            for (final c in all)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: KeyedSubtree(
                  key: sel == c.id ? _selectedKey : null,
                  child: BuChip(
                    key: ValueKey('forum-chip-${c.id}'),
                    label: c.name,
                    selected: sel == c.id,
                    onTap: () => widget.onSelected(c.id),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
