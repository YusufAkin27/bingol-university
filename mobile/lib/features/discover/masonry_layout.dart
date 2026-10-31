import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';

/// Keşfet masonry ızgarası (Stitch v3 kesfet2): iki sütun, her kutu o ana kadar en kısa sütuna konur. Kutu
/// yüksekliği (genişlik / oran) önceden bilindiğinden yerleşim ÖNCEDEN hesaplanır; paket gerekmez ve fotoğraflar
/// çözülünce kutular zıplamaz. Tembel çizim için `SliverGrid` + [MasonryGridDelegate] kullanılır.

/// Sütun sayısı ve aralıklar (dp): yan kenar 12, sütun ve satır arası 8.
const int kMasonryColumns = 2;
const double kMasonryGap = 8;
const double kMasonrySide = 12;

/// Bir kutunun yerleşimi: sütun, üst ofset, yükseklik.
class MasonryPlacement {
  const MasonryPlacement(this.column, this.top, this.height);

  final int column;
  final double top;
  final double height;

  double get bottom => top + height;
}

/// Açgözlü yerleşim: her kutu, o ana kadar en kısa (alt kenarı en yukarıdaki) sütuna; eşitlikte baştaki sütuna.
/// Üst ofsetler indekse göre azalmaz (azalmayan dizi), bu yüzden görünür aralık ikili aramayla bulunur.
List<MasonryPlacement> masonryPlace(List<double> heights, {int columns = kMasonryColumns, double gap = kMasonryGap}) {
  final bottoms = List<double>.filled(columns, 0);
  final out = <MasonryPlacement>[];
  for (final h in heights) {
    var c = 0;
    for (var i = 1; i < columns; i++) {
      if (bottoms[i] < bottoms[c] - .001) c = i;
    }
    out.add(MasonryPlacement(c, bottoms[c], h));
    bottoms[c] += h + gap;
  }
  return out;
}

/// Sütun genişliği: (toplam - aralıklar) / sütun sayısı. 366 dp içerik genişliğinde 179 dp.
double masonryColumnWidth(double crossExtent, {int columns = kMasonryColumns, double gap = kMasonryGap}) =>
    (crossExtent - gap * (columns - 1)) / columns;

/// İlk [count] kutu yerleştirildikten sonra sütun alt kenarları arasındaki en büyük fark (dp).
double masonryColumnDiff(List<double> heights, int count, {double gap = kMasonryGap}) {
  final p = masonryPlace(heights.take(count).toList(), gap: gap);
  final b = List<double>.filled(kMasonryColumns, 0);
  for (final e in p) {
    b[e.column] = e.bottom + gap;
  }
  return (b.reduce(math.max) - b.reduce(math.min)).abs();
}

/// Tam genişlikli bandın (örn. "Tanıyor Olabilirsin") masonry'yi böleceği kutu sayısı (SARTNAME 07): en erken
/// [min] kutudan sonra, sütun yükseklikleri farkı [tolerance] dp içinde kalan nokta; yoksa [max] içinde farkı en küçük
/// olan nokta. Kutu sayısı [min]'den azsa hepsi (bant sonda).
int masonrySplitIndex(List<double> heights, {int min = 4, int max = 10, double tolerance = 16}) {
  if (heights.length <= min) return heights.length;
  final limit = math.min(max, heights.length);
  var best = min;
  var bestDiff = double.infinity;
  for (var k = min; k <= limit; k++) {
    final d = masonryColumnDiff(heights, k);
    if (d <= tolerance) return k;
    if (d < bestDiff - .001) {
      bestDiff = d;
      best = k;
    }
  }
  return best;
}

/// `SliverGrid` için masonry düzeni. [ratios] genişlik/yükseklik oranlarıdır; kutu yüksekliği = sütun genişliği / oran.
class MasonryGridDelegate extends SliverGridDelegate {
  MasonryGridDelegate({required this.ratios, this.gap = kMasonryGap});

  final List<double> ratios;
  final double gap;

  SliverGridLayout? _layout;
  double? _layoutExtent;
  bool? _layoutReverse;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final reverse = axisDirectionIsReversed(constraints.crossAxisDirection);
    final cached = _layout;
    if (cached != null && _layoutExtent == constraints.crossAxisExtent && _layoutReverse == reverse) return cached;
    final colW = masonryColumnWidth(constraints.crossAxisExtent, gap: gap);
    final placements = masonryPlace([for (final r in ratios) colW / r], gap: gap);
    _layoutExtent = constraints.crossAxisExtent;
    _layoutReverse = reverse;
    return _layout = _MasonryGridLayout(
      placements: placements,
      columnWidth: colW,
      gap: gap,
      crossExtent: constraints.crossAxisExtent,
      reverse: reverse,
    );
  }

  @override
  bool shouldRelayout(MasonryGridDelegate old) => old.gap != gap || !listEquals(old.ratios, ratios);
}

class _MasonryGridLayout extends SliverGridLayout {
  _MasonryGridLayout({
    required this.placements,
    required this.columnWidth,
    required this.gap,
    required this.crossExtent,
    required this.reverse,
  })  : _tops = [for (final p in placements) p.top],
        _maxHeight = placements.fold<double>(0, (m, p) => math.max(m, p.height));

  final List<MasonryPlacement> placements;
  final double columnWidth;
  final double gap;
  final double crossExtent;
  final bool reverse;
  final List<double> _tops;
  final double _maxHeight;

  /// [_tops] içinde `>= value` olan ilk indeks (alt sınır).
  int _lowerBound(double value) {
    var lo = 0, hi = _tops.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_tops[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    if (placements.isEmpty) return 0;
    // Üstü (scrollOffset - en yüksek kutu) öncesinde kalan kutuların alt kenarı mutlaka scrollOffset'in üstündedir.
    return _lowerBound(scrollOffset - _maxHeight).clamp(0, placements.length - 1);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    if (placements.isEmpty) return 0;
    // Üst kenarı scrollOffset'ten küçük olan son kutu.
    return (_lowerBound(scrollOffset) - 1).clamp(0, placements.length - 1);
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final p = placements[index];
    var x = p.column * (columnWidth + gap);
    if (reverse) x = crossExtent - x - columnWidth;
    return SliverGridGeometry(scrollOffset: p.top, crossAxisOffset: x, mainAxisExtent: p.height, crossAxisExtent: columnWidth);
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    var m = 0.0;
    for (var i = 0; i < math.min(childCount, placements.length); i++) {
      m = math.max(m, placements[i].bottom);
    }
    return m;
  }
}
