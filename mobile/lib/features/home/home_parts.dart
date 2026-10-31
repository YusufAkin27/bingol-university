import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../news/icerik_parts.dart' show newsHero;

/// Yuvarlak (16) arama kutusu; dokununca arama sayfasına gider.
class HomeSearchBox extends StatelessWidget {
  const HomeSearchBox({super.key, required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .985,
        child: Material(
          color: t.sf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md)),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.button),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 18, color: t.mut),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hızlı erişim karosu tonları: tema belirteçlerinden (açık/koyu kendiliğinden). Ana Sayfa yalnız `blue` kullanır.
enum HomeTone {
  red,
  green,
  blue,
  amber,
  aqua;

  /// Ad = ailenin adı (kırmızı marka, yeşil, mavi, amber, su mavisi); değerler `BuTintId` tablosundan gelir.
  BuTint tint(BuTokens t) => switch (this) {
        HomeTone.red => t.tint(BuTintId.brand),
        HomeTone.green => t.tint(BuTintId.green),
        HomeTone.blue => t.tint(BuTintId.blue),
        HomeTone.amber => t.tint(BuTintId.amber),
        HomeTone.aqua => t.tint(BuTintId.aqua),
      };
}

/// Hızlı erişim karosu: çerçevesiz; yumuşak tonlu simge karosu + etiket (kart içinde kart yok).
class HomeQuickTile extends StatelessWidget {
  const HomeQuickTile({super.key, required this.icon, required this.label, required this.tone, required this.onTap});

  final IconData icon;
  final String label;
  final HomeTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tn = tone.tint(t);
    // Etiket kutusu en az 30 dp; iki satırın (sıkıştırılmış 1,3x ölçekte) yüksekliğinden küçük olamaz, yoksa taşar.
    final labelStyle = Theme.of(context).textTheme.labelSmall!;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final labelBoxH = math.max(30.0, 2 * scaler.scale(labelStyle.fontSize ?? 11) * 1.15 + 1);
    // Sabit boyutlu kutu: çok büyük yazı ölçeğinde taşmasın.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: tn.bg, borderRadius: BorderRadius.circular(BuRadius.md)),
                child: Icon(icon, size: 20, color: tn.fg),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: labelBoxH,
                child: Center(
                  // Çok sözcüklü etiket iki satıra sarar; tek sözcük asla ortadan bölünmez (küçülür).
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final w in label.split(' '))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(w,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, height: 1.15, color: t.ink)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Hızlı erişim ızgarası: beş karo tek satırda, etiketler okunur boyutta sığarsa; sığmazsa (dar ekran, büyük yazı)
/// 3 + 2 iki satır. Yazı hiçbir durumda 11.5 sp altına küçülmez, karolar aynı boyda kalır.
class HomeQuickGrid extends StatefulWidget {
  const HomeQuickGrid({super.key, required this.tiles, required this.labels});

  /// Karolar ([HomeQuickTile]) ve aynı sırada etiketleri (sığma ölçümü için).
  final List<Widget> tiles;
  final List<String> labels;

  @override
  State<HomeQuickGrid> createState() => _HomeQuickGridState();
}

class _HomeQuickGridState extends State<HomeQuickGrid> with SingleTickerProviderStateMixin {
  // 4 dp: çerçevesiz karolarda etiketler komşuya yapışmasın diye karo içi 2 + 2 dp ek boşluk da var.
  static const _gap = 4.0;
  static const _totalMs = 490; // 120 ms bekleme (blok girişiyle çakışmasın) + 4x30 ms + 250 ms

  List<Widget> get tiles => widget.tiles;
  List<String> get labels => widget.labels;

  // Giriş: karolar 30 ms arayla hafifçe büyüyerek belirir; tek denetleyici, yalnız bir kez (yenilemede oynamaz).
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: _totalMs));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (BuMotion.reduced(context)) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Widget _tileIn(int i, Widget child) {
    final start = ((120 + i * 30) / _totalMs).clamp(0.0, 1.0);
    final end = (start + 250 / _totalMs).clamp(0.0, 1.0);
    final a = CurvedAnimation(parent: _in, curve: Interval(start, end, curve: BuMotion.emphasizedDecelerate));
    return FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween<double>(begin: .9, end: 1).animate(a), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final style = Theme.of(context).textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600);
      final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
      var longest = 0.0;
      for (final label in labels) {
        for (final w in label.split(' ')) {
          final tp = TextPainter(
            text: TextSpan(text: w, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          longest = math.max(longest, tp.width);
        }
      }
      final n = tiles.length;
      final inner = (c.maxWidth - _gap * (n - 1)) / n - 4; // karo yatay iç boşluğu 2 + 2
      final cols = longest <= inner ? n : 3;
      final rows = <Widget>[];
      for (var start = 0; start < n; start += cols) {
        if (start > 0) rows.add(const SizedBox(height: _gap));
        rows.add(Row(children: [
          for (var j = 0; j < cols; j++) ...[
            if (j > 0) const SizedBox(width: _gap),
            Expanded(child: start + j < n ? _tileIn(start + j, tiles[start + j]) : const SizedBox.shrink()),
          ],
        ]));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// Sakin metin düğmesi: yazı (+ isteğe bağlı küçük ok), dolgu/çerçeve yok; dokunma alanı >= 48 dp.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap, required this.color, this.chevron = false});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final link = Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(BuRadius.xs),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(color: color))),
                if (chevron) ...[
                  const SizedBox(width: 2),
                  Icon(buDirIcon(context, LucideIcons.chevronRight), size: 16, color: color),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
    return onTap == null ? Opacity(opacity: .5, child: link) : link;
  }
}

/// Bölüm başlığı (17/800) + sağda sakin "Tümü" metin düğmesi (soluk renk + küçük ok).
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, required this.action, required this.onAction, this.onLongPress});

  final String title;
  final String action;
  final VoidCallback onAction;

  /// Başlığa uzun basma: "Ana sayfayı düzenle" (düzenleme alt sayfasını açar).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Row(children: [
      Expanded(
        child: Semantics(
          header: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(fontSize: 17, color: t.ink)),
              ),
            ),
          ),
        ),
      ),
      _TextLink(label: action, onTap: onAction, color: t.mut, chevron: true),
    ]);
  }
}

/// Bir Ana Sayfa bölümünün yuvası: görünürken içeriği kurar; gizlenince/eklenince yükseklik + solma geçişi
/// (`AnimatedSize` + `AnimatedSwitcher`, "animasyonları azalt" açıkken anında). Gizliyken [builder] ÇAĞRILMAZ:
/// bölümün alt ağacı (ve tembel veri isteği) hiç kurulmaz.
class HomeSectionSlot extends StatelessWidget {
  const HomeSectionSlot({super.key, required this.visible, required this.builder});

  final bool visible;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    // "Animasyonları azalt": geçişsiz (sıfır süreli AnimatedSize yerleşim sırasında yeniden çizim tetikler).
    if (BuMotion.reduced(context)) return visible ? KeyedSubtree(key: const ValueKey('on'), child: builder()) : const SizedBox(width: double.infinity);
    const d = BuMotion.medium;
    return AnimatedSize(
      duration: d,
      curve: BuMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: BuMotion.standard,
        switchOutCurve: BuMotion.standard,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, if (current != null) current],
        ),
        child: visible
            ? KeyedSubtree(key: const ValueKey('on'), child: builder())
            : const SizedBox(key: ValueKey('off'), width: double.infinity),
      ),
    );
  }
}

/// Bütün bölümler gizliyken sakin boş durum: tek cümle + "Bölüm ekle".
class HomeEmptyHome extends StatelessWidget {
  const HomeEmptyHome({super.key, required this.title, required this.actionLabel, required this.onAction});

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          ExcludeSemantics(child: Icon(LucideIcons.layoutDashboard, size: 28, color: t.mut)),
          const SizedBox(height: 12),
          Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: BuType.heading.copyWith(color: t.ink))),
          const SizedBox(height: 16),
          BuButton(label: actionLabel, kind: BuButtonKind.soft, compact: true, icon: LucideIcons.plus, onPressed: onAction),
        ]),
      ),
    );
  }
}

/// Duyurular (en çok 3): tek yüzeyde başlık + tarih satırları; ayırıcı çizgi yok, boşlukla ayrılır.
class HomeAnnouncementList extends StatelessWidget {
  const HomeAnnouncementList({super.key, required this.items});

  final List<({String title, String date, VoidCallback onTap})> items;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final it in items)
          InkWell(
            onTap: it.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
                  const SizedBox(height: 2),
                  Text(it.date, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Bugünkü dersler (en çok 3 satır): saat aralığı (tabular) + ders adı + derslik; süren ders marka renginde.
class HomeClassList extends StatelessWidget {
  const HomeClassList({super.key, required this.rows, required this.onTap});

  final List<({String time, String title, String place, bool now})> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in rows)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 96,
                  child: Text(r.time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BuType.label.copyWith(fontWeight: FontWeight.w700, color: r.now ? t.pr : t.mut, fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: t.ink)),
                    if (r.place.isNotEmpty) Text(r.place, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Ana Sayfa yükleniyor iskeleti: üst çubuk, arama, vitrin kartı, hızlı erişim, haber, etkinlik.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.commonLoading,
      child: ExcludeSemantics(
        child: BuSkeletonScope(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, kNavInset),
            children: [
              const Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 80, height: 10),
                    SizedBox(height: 8),
                    BuSkeleton(width: 170, height: 22, radius: 11),
                  ]),
                ),
                BuSkeleton.circle(40),
                SizedBox(width: 8),
                BuSkeleton.circle(40),
              ]),
              const SizedBox(height: 16),
              const BuSkeleton(height: 52, radius: BuRadius.md),
              const SizedBox(height: 16),
              const BuSkeleton(height: 190, radius: BuRadius.lg),
              const SizedBox(height: 24),
              Row(children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  const Expanded(child: BuSkeleton(height: 84, radius: BuRadius.md)),
                ],
              ]),
              const SizedBox(height: 24),
              const Row(children: [BuSkeleton(width: 150, height: 16), Spacer(), BuSkeleton(width: 40, height: 12)]),
              const SizedBox(height: 12),
              const BuSkeleton(height: 228, radius: BuRadius.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana Sayfa boş/hata durumu: tek satır (soluk simge + tek cümle); isteğe bağlı metin düğmesi ya da dokunma oku.
class HomeEmptyCard extends StatelessWidget {
  const HomeEmptyCard({
    super.key,
    required this.icon,
    required this.headline,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.live = false,
  });

  final IconData icon;
  final String headline;

  /// Verilirse sağda sakin metin düğmesi ("Tekrar dene" gibi); [onAction] null ise soluk.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Satırın tamamı dokunulabilirse (ok görünür).
  final VoidCallback? onTap;

  /// Hata cümlesi ekran okuyucuya canlı bölge olarak duyurulsun.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget text = Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut));
    if (live) text = Semantics(liveRegion: true, child: text);
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: SizedBox(
          width: double.infinity,
          child: Row(children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: t.mut)),
            const SizedBox(width: 12),
            Expanded(child: text),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              _TextLink(label: actionLabel!, onTap: onAction, color: t.pr),
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              ExcludeSemantics(child: Icon(buDirIcon(context, LucideIcons.chevronRight), size: 20, color: t.mut)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Duyurular alanı durum satırı: boşsa tek cümle; hata varsa hata cümlesi + "Yeniden dene" metin düğmesi.
class HomeNewsStateCard extends StatelessWidget {
  const HomeNewsStateCard({super.key, required this.emptyText, this.errorText, this.retryLabel, this.onRetry});

  final String emptyText;
  final String? errorText;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (errorText != null) {
      return HomeEmptyCard(icon: LucideIcons.cloudOff, headline: errorText!, actionLabel: retryLabel ?? '', onAction: onRetry, live: true);
    }
    return HomeEmptyCard(icon: LucideIcons.inbox, headline: emptyText);
  }
}

/// Üst çubuk: "BÜ KAMPÜS" yazısı + selamlama (tek blok); sağda zil ve profil avatarı. Logo karosu ve alt başlık yok.
class HomeBrandHeader extends StatelessWidget {
  const HomeBrandHeader({super.key, required this.bell, required this.displayName, required this.onProfile, required this.profileLabel, this.hello});

  final Widget bell;
  final String? displayName;
  final VoidCallback onProfile;
  final String profileLabel;

  /// "Merhaba, Ayşe"; null ise yalnız marka yazısı görünür.
  final String? hello;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final helloStyle = BuType.display.copyWith(fontSize: 24, letterSpacing: -.4, color: t.ink);
    final wordmark = Text('BÜ KAMPÜS', maxLines: 1, style: tx.labelSmall!.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2, color: t.pr));
    Widget helloText() => Semantics(
          header: true,
          child: Text(hello!, maxLines: 2, overflow: TextOverflow.ellipsis, style: helloStyle),
        );
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      bell,
      const SizedBox(width: 4),
      Semantics(
        button: true,
        label: profileLabel,
        excludeSemantics: true,
        onTap: onProfile,
        child: BuPressable(
          onTap: onProfile,
          child: SizedBox(width: 48, height: 48, child: Center(child: BuAvatar(name: displayName, size: 40))),
        ),
      ),
    ]);
    return LayoutBuilder(builder: (context, c) {
      // Selamlama yan yana sığmıyorsa (dar ekran / büyük yazı: kelime ortadan bölünecekse ya da 2 satırı aşarsa)
      // simgeler üst satırda kalır, selamlama altta tam genişlikte yazılır.
      var stacked = false;
      if (hello != null) {
        // Simge grubu: zil (+ düzenleme düğmesi) + avatar; ölçüm için sabit pay.
        final avail = c.maxWidth - 8 - 48 * 3 - 4 * 2;
        final scaler = MediaQuery.textScalerOf(context);
        TextPainter tp(String text, int? lines) => TextPainter(
              text: TextSpan(text: text, style: helloStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
              maxLines: lines,
            )..layout(maxWidth: avail > 0 ? avail : 1);
        final words = hello!.split(' ');
        final widest = words.map((w) => (TextPainter(text: TextSpan(text: w, style: helloStyle), textDirection: Directionality.of(context), textScaler: scaler)..layout()).width).fold<double>(0, math.max);
        stacked = avail <= 0 || widest > avail || tp(hello!, null).computeLineMetrics().length > 2;
      }
      if (stacked) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: wordmark), actions]),
          helloText(),
        ]);
      }
      return Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            wordmark,
            if (hello != null) helloText(),
          ]),
        ),
        const SizedBox(width: 8),
        actions,
      ]);
    });
  }
}

/// "Günün Yemek Menüsü" vitrin kartı (Ana Sayfa'nın tek dolgulu yüzeyi): kırmızı gradyan (ya da menü fotoğrafı),
/// başlık, tek satır künye (çeşit sayısı · saat), en çok 3 yemek adı ve düz "Menü Detayı" bağlantısı.
class HomeMealHero extends StatelessWidget {
  const HomeMealHero({
    super.key,
    required this.chip,
    required this.title,
    required this.time,
    required this.dishes,
    required this.detailLabel,
    required this.onTap,
    this.photo,
    this.photoLabel,
  });

  final String chip;
  final String title;
  final String time;
  final List<String> dishes;
  final String detailLabel;
  final VoidCallback onTap;
  final Widget? photo;
  final String? photoLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = t.onMedia;
    final shown = dishes.take(3).toList();
    final extra = dishes.length - shown.length;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('$chip · $time', maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: fg.withValues(alpha: .88))),
        const SizedBox(height: 4),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(fontWeight: FontWeight.w800, color: fg)),
        const SizedBox(height: 12),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Text(shown[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w600, color: fg)),
        ],
        if (extra > 0) ...[
          const SizedBox(height: 4),
          Text('+$extra', style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: fg.withValues(alpha: .85))),
        ],
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(detailLabel, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
              const SizedBox(width: 4),
              Icon(buDirIcon(context, LucideIcons.chevronRight), size: 18, color: fg),
            ]),
          ),
        ),
      ]),
    );
    return Semantics(
      button: true,
      label: [if (photo != null && photoLabel != null) photoLabel!, title, chip, dishes.join(', ')].join('. '),
      onTap: onTap,
      excludeSemantics: true,
      child: BuPressable(
        scale: .98,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BuRadius.lg),
          child: Stack(children: [
            Positioned.fill(
              child: photo != null
                  ? Semantics(image: true, label: photoLabel, child: photo)
                  : DecoratedBox(decoration: BoxDecoration(gradient: t.hero)),
            ),
            if (photo != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.scrim.withValues(alpha: .35), t.scrim.withValues(alpha: .8)],
                    ),
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: photo != null ? ConstrainedBox(constraints: const BoxConstraints(minHeight: 200), child: Align(alignment: AlignmentDirectional.bottomStart, child: content)) : content,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Öne çıkan haber kartı (yatay kaydırma): görsel, başlık, tarih. Tür etiketi, ok ve gradyan yok.
class HomeNewsCard extends StatelessWidget {
  const HomeNewsCard({
    super.key,
    required this.title,
    required this.dateText,
    required this.imageUrl,
    required this.onTap,
    this.width = 280,
    this.heroId,
  });

  /// Görsel yüksekliği.
  static const imageHeight = 140.0;

  /// Metin bölümü (başlık 2 satır + tarih + iç boşluklar) 1x ölçekte; şerit yüksekliği için.
  static const _titleBox = 39.0; // 15 sp x 1,3 x 2 satır
  static const _dateBox = 17.0;
  static const _fixed = 12 + 6 + 14.0; // üst boşluk + başlık/tarih arası + alt boşluk
  static const _maxScale = 1.5;

  /// Kartın (çerçeve dahil) yüksekliği; [scale] sistem yazı ölçeği (en çok 1,5 hesaba katılır).
  static double heightFor(double scale) => imageHeight + _fixed + (_titleBox + _dateBox) * scale.clamp(1.0, _maxScale) + 2;

  /// Verilirse görsel, haber detayının kapağına paylaşılan geçişle (Hero) uçar.
  final int? heroId;
  final String title;
  final String dateText;
  final String? imageUrl;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxScale,
      child: Builder(builder: (context) {
        final scaler = MediaQuery.textScalerOf(context);
        return SizedBox(
          width: width,
          child: BuCard(
            radius: BuRadius.lg,
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BuRadius.lg - 1),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: imageHeight,
                  child: hasImg
                      ? (heroId == null
                          ? BuImage(imageUrl, width: double.infinity, height: imageHeight, maxDecodeWidth: 700)
                          : newsHero(
                              id: heroId!,
                              radius: BuRadius.lg - 1,
                              child: BuImage(imageUrl, width: double.infinity, height: imageHeight, maxDecodeWidth: 700),
                            ))
                      : ColoredBox(color: t.sf2, child: Center(child: Icon(LucideIcons.newspaper, size: 40, color: t.mut.withValues(alpha: .6)))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      height: scaler.scale(_titleBox),
                      child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.heading.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3, color: t.ink)),
                    ),
                    const SizedBox(height: 6),
                    Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontWeight: FontWeight.w400, color: t.mut)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

/// Katılımcı avatar yığını (en çok 3) + sayı metni.
class HomeAvatarStack extends StatelessWidget {
  const HomeAvatarStack({super.key, required this.avatars, this.total = 0});

  final List<Map<String, dynamic>> avatars;

  /// Kullanılmıyor (ref: yalnız avatarlar + yanında toplam metni); eski çağrılar için duruyor.
  final int total;

  static const _d = 30.0;
  static const _step = 20.0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final shown = avatars.take(3).toList();
    final count = shown.length;
    if (count == 0) return Icon(LucideIcons.users, size: 18, color: t.mut);
    return SizedBox(
      width: _d + _step * (count - 1),
      height: _d,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          PositionedDirectional(
            start: i * _step,
            child: Container(
              width: _d,
              height: _d,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: t.sf),
              child: BuAvatar(name: shown[i]['displayName'] as String?, url: shown[i]['avatarUrl'] as String?, size: _d - 4),
            ),
          ),
      ]),
    );
  }
}

/// "Yaklaşan Etkinlik" kartı: tarih karosu, (varsa) düzenleyen satırı, başlık, konum, katılımcılar + eylem düğmesi.
class HomeEventCard extends StatelessWidget {
  const HomeEventCard({
    super.key,
    required this.title,
    required this.onTap,
    this.host,
    this.month,
    this.day,
    this.whenLine,
    this.location,
    this.footer,
  });

  final String title;
  final VoidCallback? onTap;
  final String? host;
  final String? month;
  final String? day;
  final String? whenLine;
  final String? location;

  /// Alt satır (avatarlar + katılımcı sayısı + düğme).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (month != null && day != null) ...[
            Container(
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.md)),
              child: Column(children: [
                Text(month!, maxLines: 1, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onSoft)),
                Text(day!, maxLines: 1, style: tx.headlineMedium!.copyWith(fontWeight: FontWeight.w800, height: 1.1, color: t.pr)),
                if (whenLine != null) Text(whenLine!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.onSoft)),
              ]),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (host != null) ...[
                Text(host!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
                const SizedBox(height: 2),
              ],
              Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.titleLarge!.copyWith(fontWeight: FontWeight.w800, height: 1.2, color: t.ink)),
              if (location != null && location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(LucideIcons.mapPin, size: 15, color: t.mut),
                  const SizedBox(width: 6),
                  Expanded(child: Text(location!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut))),
                ]),
              ],
            ]),
          ),
        ]),
        if (footer != null) ...[const SizedBox(height: 16), footer!],
      ]),
    );
  }
}

/// Yatay haber şeridi: kenarlarda yumuşak solma (kaydırılabilir olduğunu ima eder) ve başlangıç kenarından çıkan
/// kart hafifçe küçülür (en çok %6, yalnız `transform`). Kaydırma denetleyicisi dinlenir, kartlar yeniden kurulmaz;
/// "animasyonları azalt" açıkken küçülme yoktur. Kartların toplam genişliği: [itemExtent] + [gap].
class HomeNewsStrip extends StatefulWidget {
  const HomeNewsStrip({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.itemExtent = 280,
    this.gap = 12,
    this.hPad = 20,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemExtent;
  final double gap;
  final double hPad;

  @override
  State<HomeNewsStrip> createState() => _HomeNewsStripState();
}

class _HomeNewsStripState extends State<HomeNewsStrip> {
  final _c = ScrollController();

  @override
  void initState() {
    super.initState();
    // İlk karede kaydırma boyutu bilinince kenar solmaları doğru duruma gelsin (içerik sığıyorsa görünmez).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _offset => _c.hasClients ? _c.offset : 0;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final reduced = BuMotion.reduced(context);
    final step = widget.itemExtent + widget.gap;
    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        ListView.separated(
          controller: _c,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: widget.hPad),
          itemCount: widget.itemCount,
          separatorBuilder: (_, __) => SizedBox(width: widget.gap),
          itemBuilder: (context, i) {
            final child = widget.itemBuilder(context, i);
            if (reduced) return child;
            return ListenableBuilder(
              listenable: _c,
              child: child,
              builder: (context, c) {
                final p = ((_offset - i * step) / step).clamp(0.0, 1.0);
                return p == 0 ? c! : Transform.scale(scale: 1 - .06 * p, child: c);
              },
            );
          },
        ),
        // Kenar solması: başlangıçta yalnız bitiş kenarı, kaydırınca başlangıç kenarı da görünür.
        for (final atStart in const [true, false])
          PositionedDirectional(
            start: atStart ? 0 : null,
            end: atStart ? null : 0,
            top: 0,
            bottom: 0,
            width: widget.hPad,
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: _c,
                builder: (context, _) {
                  final max = (_c.hasClients && _c.position.hasContentDimensions) ? _c.position.maxScrollExtent : 1.0;
                  final o = atStart ? (_offset / 24) : ((max - _offset) / 24);
                  return Opacity(
                    opacity: o.clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: atStart ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                          end: atStart ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                          colors: [t.bg, t.bg.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ]),
    );
  }
}
