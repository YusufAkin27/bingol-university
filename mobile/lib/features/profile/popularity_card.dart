import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

int? _n(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

/// Profilde "Popülerlik" satırı: sunucunun hesapladığı 0..100 puan + bileşenler (takipçi, alınan beğeni, gönderi).
///
/// Yalnız gerçek sayılar: `popularityScore` yoksa kart hiç çizilmez; bileşenlerden yanıtta olmayan gösterilmez.
/// Puan = takipçi sayısı + aldığı toplam beğeni + gönderi sayısından türetilen normalleştirilmiş değerdir.
/// [self] true ise altta puanın nasıl oluştuğunu anlatan kısa not görünür.
class PopularityCard extends StatelessWidget {
  const PopularityCard({super.key, required this.profile, this.self = false});

  /// `GET /users/me` ya da `/users/{id}` yanıtı.
  final Map<String, dynamic> profile;
  final bool self;

  /// Karta konu olacak puan (yoksa null: kart çizilmez).
  static int? scoreOf(Map<String, dynamic>? p) {
    final n = p?['popularityScore'];
    final v = n is num ? n : (n is String ? num.tryParse(n) : null);
    return v?.round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final score = scoreOf(profile);
    if (score == null) return const SizedBox.shrink();
    final t = context.bu;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final parts = <(String, int)>[
      if (_n(profile['followerCount']) != null) (l.icerikStatFollowers, _n(profile['followerCount'])!),
      if (_n(profile['likesReceived']) != null) (l.kesLikesReceived, _n(profile['likesReceived'])!),
      if (_n(profile['postCount']) != null) (l.icerikStatPosts, _n(profile['postCount'])!),
    ];
    return Semantics(
      container: true,
      label: l.kesPopularityOf('$score'),
      child: DecoratedBox(
        key: const ValueKey('popularityCard'),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BorderRadius.circular(BuRadius.md),
          border: Border.all(color: t.bd),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Expanded(
                  child: Text(l.kesPopularity, style: tt.titleSmall?.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
                ),
                Text('$score',
                    key: const ValueKey('popularityScore'),
                    style: tt.titleLarge?.copyWith(
                        color: t.ink, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                Text(' / 100', style: tt.bodySmall?.copyWith(color: t.mut)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 6,
                  child: Stack(children: [
                    Positioned.fill(child: ColoredBox(color: t.sf2)),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: score / 100,
                        child: ColoredBox(key: const ValueKey('popularityBar'), color: t.pr),
                      ),
                    ),
                  ]),
                ),
              ),
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  for (final (label, value) in parts)
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$value',
                            style: tt.titleMedium?.copyWith(
                                color: t.ink, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(color: t.mut)),
                      ]),
                    ),
                ]),
              ],
              if (self) ...[
                const SizedBox(height: 10),
                Text(l.kesPopularityHow, style: tt.bodySmall?.copyWith(color: t.mut, fontSize: 12)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
