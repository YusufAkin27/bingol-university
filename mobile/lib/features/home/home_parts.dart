import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import '../news/icerik_parts.dart' show newsHero;

/// Ana Sayfa (Stitch v3, `docs/design/BIREBIR_HOME.md`): tek yüzey ailesi = beyaz (`sf`) + 1 dp `bd` çerçeve + 16 köşe,
/// gölge yok; bölüm başlığı 17/600; yan boşluk 20; bölümler arası 24.

/// Bölümlerin yüzeyi: beyaz + 1 dp çerçeve + 16 köşe. [onTap] verilirse tümü dokunulur.
class HomeSurface extends StatelessWidget {
  const HomeSurface({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.color});

  final Widget child;

  /// Zemin (varsayılan `sf`; seçici üstündeki seçili liste `bg`).
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Material(
      color: color ?? t.sf,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BuRadius.md), side: BorderSide(color: t.bd)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Yüzey içi satır ayırıcı: 1 dp `bd`.
class HomeHairline extends StatelessWidget {
  const HomeHairline({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: 1, child: ColoredBox(color: context.bu.bd));
}

/// Arama kutusu: 48 dp, beyaz, 1 dp çerçeve, 16 köşe; dokununca arama sayfasına gider.
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
              constraints: const BoxConstraints(minHeight: BuSize.search),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(LucideIcons.search, size: 16, color: t.mut),
                  const SizedBox(width: 12),
                  Expanded(child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 15, color: t.mut))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hızlı erişim karosu: beyaz, 1 dp çerçeve, 16 köşe; düz ink simge (renkli blob yok) + 12 sp/500 etiket.
class HomeQuickTile extends StatelessWidget {
  const HomeQuickTile({super.key, required this.icon, required this.label, required this.onTap, this.lines = 1});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Etiket satır sayısı (1 ya da 2); satırdaki bütün karolarda aynı verilir ki boyları eşit olsun.
  final int lines;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final style = BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.15, color: t.ink);
    // En çok 1,3x ölçek: kutu sabit yükseklikli, taşmaz.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    final labelBoxH = lines * scaler.scale(style.fontSize!) * 1.15 + 1;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: BuPressable(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(BuRadius.md), border: Border.all(color: t.bd)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 20, color: t.ink),
                const SizedBox(height: 6),
                SizedBox(
                  height: labelBoxH,
                  child: Center(
                    // Çok sözcüklü etiket satırlara bölünür; tek sözcük asla ortadan bölünmez (küçülür).
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final w in label.split(' ')) FittedBox(fit: BoxFit.scaleDown, child: Text(w, maxLines: 1, style: style)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hızlı erişim ızgarası: 5 eşit sütun, 8 dp aralık; etiketler okunur boyutta sığmazsa (dar ekran, büyük yazı)
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
  static const _gap = 6.0; // Stitch 8; 5 karoda "Etkinlikler" 12 sp tek satıra sığsın diye 6
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
      final style = BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
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
      final inner = (c.maxWidth - _gap * (n - 1)) / n - 4 - 2; // karo yatay iç boşluğu 2 + 2, çerçeve 1 + 1
      // Etiket karoda en çok 11.5 sp'ye kadar küçülebilir (FittedBox): sığma kararı buna göre.
      final cols = longest * (11.5 / 12) <= inner ? n : 3;
      final rows = <Widget>[];
      for (var start = 0; start < n; start += cols) {
        if (start > 0) rows.add(const SizedBox(height: _gap));
        rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var j = 0; j < cols; j++) ...[
              if (j > 0) const SizedBox(width: _gap),
              Expanded(child: start + j < n ? _tileIn(start + j, tiles[start + j]) : const SizedBox.shrink()),
            ],
          ]),
        ));
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// Sakin metin düğmesi: yazı, dolgu/çerçeve yok; dokunma alanı >= 48 dp.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap, required this.color, this.style});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final TextStyle? style;

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
          constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: BuSize.touch),
          child: Center(
            widthFactor: 1,
            child: Padding(
              // Metin satırın sağ kenarına yaslı (Stitch); dokunma alanı sol tarafa taşar.
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: (style ?? BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500)).copyWith(color: color)),
            ),
          ),
        ),
      ),
    );
    return onTap == null ? Opacity(opacity: .5, child: link) : link;
  }
}

/// Bölüm başlığı (17/600) + sağda bağlantı (13/500): `Tümü` soluk, `Menüyü aç` marka rengi; ya da düz yan metin
/// ([trailing], örn. gün adı). Satır 48 dp (dokunma hedefi); metin satırda ortalıdır, bu yüzden bölüm üst boşluğu 12'dir.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.action, this.onAction, this.onLongPress, this.accent = false, this.trailing});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  /// Başlığa uzun basma: "Ana sayfayı düzenle" (düzenleme sayfasını açar).
  final VoidCallback? onLongPress;

  /// Bağlantı marka renginde mi (`Menüyü aç`).
  final bool accent;

  /// Bağlantı yerine soluk düz metin (örn. "Pazartesi").
  final String? trailing;

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
              constraints: const BoxConstraints(minHeight: BuSize.touch),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
              ),
            ),
          ),
        ),
      ),
      if (action != null) _TextLink(label: action!, onTap: onAction, color: accent ? t.pr : t.mut),
      if (action == null && trailing != null)
        Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Text(trailing!, maxLines: 1, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut))),
    ]);
  }
}

/// Bir Ana Sayfa bölümünün yuvası: görünürken içeriği kurar; gizlenince/eklenince yükseklik + solma geçişi
/// (`AnimatedSize` + `AnimatedSwitcher`, 220 ms; "animasyonları azalt" açıkken anında). Gizliyken [builder] ÇAĞRILMAZ:
/// bölümün alt ağacı (ve tembel veri isteği) hiç kurulmaz.
class HomeSectionSlot extends StatelessWidget {
  const HomeSectionSlot({super.key, required this.visible, required this.builder});

  final bool visible;
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    // "Animasyonları azalt": geçişsiz (sıfır süreli AnimatedSize yerleşim sırasında yeniden çizim tetikler).
    if (BuMotion.reduced(context)) return visible ? KeyedSubtree(key: const ValueKey('on'), child: builder()) : const SizedBox(width: double.infinity);
    const d = Duration(milliseconds: 220);
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

/// Bütün bölümler gizliyken sakin boş durum (illüstrasyon yok): "Ana sayfan boş", açıklama, "Bölüm ekle", "Varsayılana dön".
class HomeEmptyHome extends StatelessWidget {
  const HomeEmptyHome({super.key, required this.title, required this.subtitle, required this.actionLabel, required this.onAction, required this.resetLabel, required this.onReset});

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final String resetLabel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: BuType.title.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: t.ink))),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: BuType.body.copyWith(color: t.mut)),
        const SizedBox(height: 16),
        BuButton(label: actionLabel, onPressed: onAction),
        const SizedBox(height: 8),
        _TextLink(label: resetLabel, onTap: onReset, color: t.mut, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w400)),
      ]),
    );
  }
}

/// "Bugün" tek bakış yüzeyi: en çok 3 satır (etiket soluk 14 + değer 14/500 sağa hizalı), aralarında 1 dp çizgi.
/// Etiket sarmaz (içeriğine göre genişler; yalnız çok darda kırpılır), değer en çok 2 satır.
class HomeTodayCard extends StatelessWidget {
  const HomeTodayCard({super.key, required this.rows});

  final List<({String label, String value, VoidCallback onTap, bool muted})> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return HomeSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const HomeHairline(),
          Semantics(
            button: true,
            label: '${rows[i].label}: ${rows[i].value}',
            excludeSemantics: true,
            onTap: rows[i].onTap,
            child: InkWell(
              onTap: rows[i].onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BuSize.touch),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: LayoutBuilder(builder: (context, c) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth * .45),
                        child: Text(rows[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(rows[i].value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: BuType.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500, color: rows[i].muted ? t.mut : t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Günün menüsü: yemek adı + kcal (yoksa "–"), 1 dp çizgi, "Toplam enerji" satırı. Kırmızı dolu vitrin yok.
class HomeMenuCard extends StatelessWidget {
  const HomeMenuCard({super.key, required this.dishes, required this.totalLabel, required this.totalValue, required this.kcalText, required this.onTap});

  /// (ad, kcal metni ya da null)
  final List<({String name, String? kcal})> dishes;

  /// Toplam satırı (null: gösterilmez): soluk etiket + sağda değer.
  final String? totalLabel;
  final String? totalValue;

  /// Kalori sütunu görünsün mü (hiçbir yemeğin kalorisi yoksa gizlenir).
  final bool kcalText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    const tab = [FontFeature.tabularFigures()];
    return HomeSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < dishes.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text(dishes[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.ink))),
            if (kcalText) ...[
              const SizedBox(width: 12),
              Text(dishes[i].kcal ?? '–', style: BuType.label.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: t.mut, fontFeatures: tab)),
            ],
          ]),
        ],
        if (totalLabel != null && totalValue != null) ...[
          const SizedBox(height: 12),
          const HomeHairline(),
          const SizedBox(height: 12),
          Row(children: [
            Text(totalLabel!, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
            const SizedBox(width: 12),
            Expanded(child: Text(totalValue!, textAlign: TextAlign.end, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: t.ink, fontFeatures: tab))),
          ]),
        ],
      ]),
    );
  }
}

/// Bugünkü dersler: saat sütunu (48 dp, 14/600) + ders adı (15/500) + soluk alt satır (derslik · öğretim üyesi).
class HomeClassList extends StatelessWidget {
  const HomeClassList({super.key, required this.rows, required this.onTap});

  final List<({String time, String title, String sub})> rows;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return HomeSurface(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const HomeHairline(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              SizedBox(
                width: 48,
                child: Text(rows[i].time, maxLines: 1, style: BuType.body.copyWith(fontWeight: FontWeight.w600, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rows[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink)),
                  if (rows[i].sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(rows[i].sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Yaklaşan etkinlikler: ay kısaltması (11/700 soluk büyük harf) + gün (19/700) sütunu, başlık 15/500, soluk "kulüp · saat".
class HomeEventList extends StatelessWidget {
  const HomeEventList({super.key, required this.rows});

  final List<({String month, String day, String title, String sub, VoidCallback? onTap})> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return HomeSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const HomeHairline(),
          InkWell(
            onTap: rows[i].onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 48,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(rows[i].month, maxLines: 1, style: BuType.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: .4, color: t.mut)),
                    Text(rows[i].day, maxLines: 1, style: BuType.title.copyWith(fontSize: 19, fontWeight: FontWeight.w700, height: 1.15, color: t.ink, fontFeatures: const [FontFeature.tabularFigures()])),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rows[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: t.ink)),
                    if (rows[i].sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rows[i].sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: t.mut)),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Duyurular (en çok 3): satır 12/16, başlık 15/400 (en çok 2 satır), tarih 12 soluk; satırlar 1 dp çizgiyle; chevron yok.
class HomeAnnouncementList extends StatelessWidget {
  const HomeAnnouncementList({super.key, required this.items});

  final List<({String title, String date, VoidCallback onTap})> items;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return HomeSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const HomeHairline(),
          InkWell(
            onTap: items[i].onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: BuSize.touch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: t.ink)),
                  const SizedBox(height: 4),
                  Text(items[i].date, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Ana Sayfa yükleniyor iskeleti: yeni yerleşimle birebir (tek iskelet tipi): başlık, arama, Bugün, hızlı erişim, menü, haber.
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
            padding: EdgeInsets.fromLTRB(20, top + 32, 20, kNavInset),
            children: [
              const Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BuSkeleton(width: 70, height: 10),
                    SizedBox(height: 8),
                    BuSkeleton(width: 180, height: 26, radius: 12),
                  ]),
                ),
                BuSkeleton.circle(40),
                SizedBox(width: 8),
                BuSkeleton.circle(40),
              ]),
              const SizedBox(height: 16),
              const BuSkeleton(height: 48, radius: BuRadius.md),
              const SizedBox(height: 24),
              const BuSkeleton(width: 60, height: 16),
              const SizedBox(height: 10),
              const BuSkeleton(height: 134, radius: BuRadius.md),
              const SizedBox(height: 24),
              const BuSkeleton(width: 110, height: 16),
              const SizedBox(height: 10),
              Row(children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  const Expanded(child: BuSkeleton(height: 64, radius: BuRadius.md)),
                ],
              ]),
              const SizedBox(height: 24),
              const BuSkeleton(width: 120, height: 16),
              const SizedBox(height: 10),
              const BuSkeleton(height: 160, radius: BuRadius.md),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana Sayfa boş/hata durumu: tek satır yüzey (soluk simge + tek cümle); isteğe bağlı marka renkli metin bağlantısı ya da ok.
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

  /// Verilirse sağda marka renkli metin bağlantısı ("Yeniden dene", "Etkinliklere göz at"); [onAction] null ise soluk.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Satırın tamamı dokunulabilirse.
  final VoidCallback? onTap;

  /// Hata cümlesi ekran okuyucuya canlı bölge olarak duyurulsun.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget text = Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(color: t.mut));
    if (live) text = Semantics(liveRegion: true, child: text);
    return HomeSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: BuSize.touch),
        child: SizedBox(
          width: double.infinity,
          child: Row(children: [
            ExcludeSemantics(child: Icon(icon, size: 18, color: t.mut)),
            const SizedBox(width: 12),
            Expanded(child: text),
            if (actionLabel != null) ...[
              const SizedBox(width: 8),
              _TextLink(label: actionLabel!, onTap: onAction, color: t.pr),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Haber/duyuru alanı durum satırı: boşsa tek cümle; hata varsa hata cümlesi + "Yeniden dene".
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

/// Üst çubuk (Stitch v3): "İyi günler" 13/400 soluk + "Merhaba, Ad" 30/700 (en çok 2 satır); sağda iki daire düğme
/// ([actions]: kalem + zil). Logo karosu, uygulama adı ve avatar yok (profil alt gezinmede).
class HomeBrandHeader extends StatelessWidget {
  const HomeBrandHeader({super.key, required this.actions, required this.hello, this.greeting});

  /// Sağdaki daire düğmeler (aralarında 8 dp).
  final List<Widget> actions;

  /// "Merhaba, Ayşe".
  final String hello;

  /// "İyi günler" (günün saatine göre); null ise gösterilmez.
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (greeting != null) Text(greeting!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
          Semantics(
            header: true,
            child: Text(hello,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BuType.display.copyWith(fontSize: 30, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: arabic ? 0 : -.4, color: t.ink)),
          ),
        ]),
      ),
      const SizedBox(width: 12),
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        actions[i],
      ],
    ]);
  }
}

/// Öne çıkan haber kartı (yatay kaydırma): 240 dp, beyaz + 1 dp çerçeve + 16 köşe, iç 12; üstte 112 dp görsel
/// (köşe 10; yoksa nötr zemin + soluk görsel simgesi), başlık 14/500 (2 satır), altta tarih 12 soluk.
class HomeNewsCard extends StatelessWidget {
  const HomeNewsCard({
    super.key,
    required this.title,
    required this.dateText,
    required this.imageUrl,
    required this.onTap,
    this.width = cardWidth,
    this.heroId,
  });

  static const cardWidth = 240.0;

  /// Görsel yüksekliği.
  static const imageHeight = 112.0;

  /// Metin bölümü 1x ölçekte (başlık 2 satır + tarih); şerit yüksekliği için.
  static const _titleBox = 37.0; // 14 sp x 1,3 x 2 satır
  static const _dateBox = 16.0;
  static const _fixed = 12 + 12 + 12 + 12.0; // iç üst + görsel-başlık + başlık-tarih + iç alt (Stitch: p-3, mb-3, mt-3)
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
        Widget image = hasImg
            ? BuImage(imageUrl, width: double.infinity, height: imageHeight, maxDecodeWidth: 600)
            : ColoredBox(color: t.sf2, child: Center(child: Icon(LucideIcons.image, size: 28, color: t.mut.withValues(alpha: .5))));
        if (hasImg && heroId != null) image = newsHero(id: heroId!, radius: 10, child: image);
        return SizedBox(
          width: width,
          child: HomeSurface(
            onTap: onTap,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: imageHeight, child: image)),
              const SizedBox(height: 12),
              SizedBox(
                height: scaler.scale(_titleBox),
                child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.body.copyWith(fontWeight: FontWeight.w500, height: 1.3, color: t.ink)),
              ),
              const SizedBox(height: 12),
              Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 12, color: t.mut)),
            ]),
          ),
        );
      }),
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
