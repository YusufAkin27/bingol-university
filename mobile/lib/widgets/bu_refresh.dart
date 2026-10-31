import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';

/// Yenilemeyi çek göstergesi (tek tip): renkler BuTokens'tan, yenileme eşiği aşılıp bırakıldığında hafif titreşim.
/// `RefreshIndicator` yerine doğrudan kullanılır (aynı davranış). Çocuk kaydırılabilir olmalı
/// (`AlwaysScrollableScrollPhysics` boş listede de çekmeyi sağlar).
class BuRefreshIndicator extends StatelessWidget {
  const BuRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.edgeOffset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final ScrollNotificationPredicate notificationPredicate;

  /// Gösterge başlangıç ofseti (üstte sabit başlık varsa).
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return RefreshIndicator(
      color: t.pr,
      backgroundColor: t.sf,
      strokeWidth: 2.4,
      edgeOffset: edgeOffset,
      notificationPredicate: notificationPredicate,
      onRefresh: () {
        BuHaptics.light();
        return onRefresh();
      },
      child: child,
    );
  }
}
