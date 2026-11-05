import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Sohbet balonlarının tek renk kaynağı (premium monochrome).
///
/// Koyu temada: gelen = koyu gri yüzey (`sf2`), giden = açık ton (`pr`, #FAFAFA) + koyu yazı.
/// Açık temada: gelen = açık gri yüzey (`sf2`), giden = koyu ton (`pr`, #09090B) + açık yazı.
/// İki tema birbirinin tersi değil, ayrı tasarlanmıştır; yine de ortak kural: giden balon her zaman
/// zeminden en çok ayrışan (birincil) tondur, gelen balon sakin gri yüzeydir. Hiçbir yerde ham renk yok.
@immutable
class ChatBubbleColors {
  const ChatBubbleColors._({
    required this.incoming,
    required this.outgoing,
    required this.onIncoming,
    required this.onOutgoing,
    required this.metaIncoming,
    required this.metaOutgoing,
    required this.readOnOutgoing,
    required this.readOnIncoming,
  });

  /// Gelen balon zemini ve üstündeki yazı / saat rengi.
  final Color incoming;
  final Color onIncoming;
  final Color metaIncoming;

  /// Giden balon zemini ve üstündeki yazı / saat rengi.
  final Color outgoing;
  final Color onOutgoing;
  final Color metaOutgoing;

  /// "Okundu" çift tiki: giden balonda (açık balonda koyu mavi, koyu balonda gök mavisi).
  final Color readOnOutgoing;

  /// "Okundu" tiki gelen/yüzey üstünde (balon dışı, örn. liste satırı).
  final Color readOnIncoming;

  static ChatBubbleColors of(BuTokens t) {
    final outgoing = t.pr;
    final lightOut = outgoing.computeLuminance() > .5;
    return ChatBubbleColors._(
      incoming: t.sf2,
      onIncoming: t.ink,
      metaIncoming: t.mut,
      outgoing: outgoing,
      onOutgoing: t.onPr,
      // Saat/tik: yazıdan biraz soluk ama AA (>= 4.5:1) kalacak kadar opak.
      metaOutgoing: t.onPr.withValues(alpha: .75),
      readOnOutgoing: lightOut ? t.readDeep : t.readSky,
      readOnIncoming: t.info,
    );
  }
}
