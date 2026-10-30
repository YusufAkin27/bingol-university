import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../widgets/bu_list.dart' show BuCountBadge;
import '../../widgets/bu_pressable.dart' show BuHaptic, BuPressable, buHaptic;
import '../chat/chatlist_widgets.dart' show ChatlistAvatar;

/// Yüzen "cam" alt gezinme (N4): kenarlardan ve alttan boşluklu, süper-elips köşeli, hafif bulanık-saydam yüzey.
/// Seçili sekmenin simgesinin arkasında marka renginde yumuşak bir gösterge KAYAR (250 ms easeOutCubic); seçili
/// simge dolgulu, seçili olmayan çizgilidir; etiketler her zaman görünür (seçili: marka rengi + kalın).
/// Profil sekmesi simge yerine kullanıcının avatarını gösterir (fotoğraf yoksa varsayılan profil görseli);
/// seçiliyken 2 px marka halkası + hafif gölge, değilken ince gri halka. Sohbet sekmesinde okunmamış rozeti vardır.
///
/// Sınıf adı ve zorunlu parametreler eski gezinmeyle aynıdır (kabuk ve testler değişmeden kullanır). Klavye
/// açılınca çubuk gizlenir. Erişilebilirlik: her sekme tek düğüm ("Sohbet, 3 okunmamış", seçili durumu, "Tab 3 of 5").
/// "Animasyonları azalt" açıkken kayma/ölçek anlıktır. Yazı ölçeği etiketlerde en çok 1.15'e sınırlanır (hap taşmasın);
/// çubuk yüksekliği ölçekle büyür.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.chatBadge,
    this.avatarUrl,
    this.avatarName,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  /// Profil sekmesi avatarının fotoğraf adresi (yok/null: varsayılan profil görseli).
  final ValueListenable<String?>? avatarUrl;

  /// Varsayılan görselin renk varyantı için ad (aynı kişi her yerde aynı rengi alır).
  final String? avatarName;

  /// Çubuğun nominal içerik yüksekliği (yazı ölçeği 1).
  static const double height = 68;

  /// Çubuğun kenarlardan ve alttan dış boşluğu.
  static const double gap = 16;

  static const double _iconSlot = 32; // gösterge + simge alanı yüksekliği
  static const double _avatar = 24; // avatar çapı (halka dışı)

  static const _outline = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.people_outline_rounded,
  ];
  static const _filled = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.chat_bubble_rounded,
    Icons.people_rounded,
  ];

  static List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açıkken çubuk yüzmez: yumuşakça kapanır (içerik alanı genişler).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSize(
      duration: BuMotion.of(context, BuMotion.short),
      curve: BuMotion.standard,
      alignment: Alignment.bottomCenter,
      child: keyboard ? const SizedBox(width: double.infinity) : _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final t = context.bu;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labels = _labels(context);
    // Büyük yazı ölçeğinde etiket bölünmesin/kırpılmasın: ölçek 1.15 ile sınırlanır, çubuk yüksekliği ölçekle büyür.
    final scale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15).scale(1);
    final labelSlot = 16 * scale;
    final barHeight = _iconSlot + 2 + labelSlot + 18; // ölçek 1: 68
    final topPad = (barHeight - (_iconSlot + 2 + labelSlot)) / 2;
    final shape =
        RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(30));
    final edge = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(30),
      side: BorderSide(
          color: dark
              ? Colors.white.withValues(alpha: .10)
              : t.bd.withValues(alpha: .9)),
    );
    // Cam: açık temada beyaz, koyu temada tonlu yüzey; ~%90 opak + arkadaki içeriğin bulanıklaştırılması.
    final surface = (dark ? t.sf3 : t.sf).withValues(alpha: .9);
    final shadows = dark
        ? [
            BoxShadow(
                color: Colors.black.withValues(alpha: .38),
                blurRadius: 26,
                offset: const Offset(0, 10))
          ]
        : [
            BoxShadow(
                color: t.shadow.withValues(alpha: .13),
                blurRadius: 28,
                offset: const Offset(0, 10)),
            BoxShadow(
                color: t.shadow.withValues(alpha: .06),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ];
    final cells = <Widget>[
      for (var i = 0; i < 5; i++)
        Expanded(
          child: _NavItem(
            key: ValueKey('nav-$i'),
            position: i,
            selected: i == index,
            label: labels[i],
            topPad: topPad,
            iconSlot: _iconSlot,
            labelSlot: labelSlot,
            onTap: () {
              if (i != index) buHaptic(BuHaptic.selection);
              onChanged(i);
            },
            outline: i < 4 ? _outline[i] : null,
            filled: i < 4 ? _filled[i] : null,
            badge: i == _chatIndex ? chatBadge : null,
            avatarUrl: i == 4 ? avatarUrl : null,
            avatarName: avatarName,
          ),
        ),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: gap),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gap, 0, gap, 0),
        child: RepaintBoundary(
          child: CustomPaint(
            key: const ValueKey('nav-pill'),
            painter: _OutsideShadow(shape, shadows),
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  // İnce kenar çizgisi içeriğin ÜSTÜNE çizilir (bulanık katmanın altında kalmasın).
                  position: DecorationPosition.foreground,
                  decoration: ShapeDecoration(shape: edge),
                  child: ColoredBox(
                    color: surface,
                    child: SizedBox(
                      height: barHeight,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.15,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Stack(
                            children: [
                              // Kayan gösterge: seçili hücrenin simge alanında (yön duyarlı: RTL'de aynalanır).
                              Positioned.fill(
                                top: topPad,
                                bottom: barHeight - topPad - _iconSlot,
                                child: ExcludeSemantics(
                                  child: AnimatedAlign(
                                    key: const ValueKey('nav-indicator'),
                                    alignment: AlignmentDirectional(
                                        -1 + 2 * index / 4, 0),
                                    duration:
                                        BuMotion.of(context, BuMotion.medium),
                                    curve: BuMotion.decelerate,
                                    child: FractionallySizedBox(
                                      widthFactor: .2,
                                      child: Center(
                                        child: FractionallySizedBox(
                                          widthFactor: .84,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                                maxWidth: 62),
                                            child: DecoratedBox(
                                              decoration: ShapeDecoration(
                                                color: t.soft,
                                                shape:
                                                    RoundedSuperellipseBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(18)),
                                              ),
                                              child: const SizedBox(
                                                  height: _iconSlot),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: cells),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gölgeyi YALNIZ şeklin dışına çizer: yarı saydam yüzeyin altından gri leke sızmaz.
class _OutsideShadow extends CustomPainter {
  const _OutsideShadow(this.shape, this.shadows);

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    final outside = Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(120)), path);
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      canvas.drawPath(path.shift(s.offset), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OutsideShadow old) => old.shape != shape || old.shadows != shadows;
}

const _chatIndex = 2; // AppTab.chat (döngüsel içe aktarmayı önlemek için)

/// Tek sekme: simge (ya da Profil'de avatar) + etiket; tüm hücre dokunma alanıdır (en az 57 x 68 dp).
class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.position,
    required this.selected,
    required this.label,
    required this.topPad,
    required this.iconSlot,
    required this.labelSlot,
    required this.onTap,
    this.outline,
    this.filled,
    this.badge,
    this.avatarUrl,
    this.avatarName,
  });

  final int position;
  final bool selected;
  final String label;
  final double topPad;
  final double iconSlot;
  final double labelSlot;
  final VoidCallback onTap;
  final IconData? outline;
  final IconData? filled;
  final ValueNotifier<int>? badge;
  final ValueListenable<String?>? avatarUrl;
  final String? avatarName;

  bool get _isProfile => outline == null;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final color = selected ? t.pr : t.mut;
    final unread = badge;
    Widget glyph = _isProfile ? _profile(context, t) : _icon(context, color);
    if (unread != null) glyph = _withBadge(context, glyph, unread);
    final visual = ExcludeSemantics(
      child: Padding(
        padding: EdgeInsets.only(top: topPad),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(height: iconSlot, child: Center(child: glyph)),
            const SizedBox(height: 2),
            SizedBox(
              height: labelSlot,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: BuMotion.of(context, BuMotion.short),
                  style: tx.labelSmall!.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: color),
                  maxLines: 1,
                  softWrap: false,
                  child: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final tab = MaterialLocalizations.of(context)
        .tabLabel(tabIndex: position + 1, tabCount: 5);
    Widget item = BuPressable(onTap: onTap, scale: .92, child: visual);
    // Ekran okuyucu: tek düğüm; rozet metni sekme etiketine eklenir ("Sohbet, 3 okunmamış").
    if (unread != null) {
      return ValueListenableBuilder<int>(
        valueListenable: unread,
        builder: (c, n, _) => _semantic(
          n > 0 && !selected
              ? '$label, ${c.l10n.p18NavUnread(n > 99 ? '99+' : '$n')}'
              : label,
          tab,
          item,
        ),
      );
    }
    return _semantic(label, tab, item);
  }

  Widget _semantic(String text, String hint, Widget child) => Semantics(
        container: true,
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: text,
        hint: hint,
        onTap: onTap,
        child: ExcludeSemantics(child: child),
      );

  Widget _icon(BuildContext context, Color color) {
    return AnimatedScale(
      scale: selected ? 1.06 : 1,
      duration: BuMotion.of(context, BuMotion.medium),
      curve: BuMotion.emphasizedDecelerate,
      child: AnimatedSwitcher(
        duration: BuMotion.of(context, BuMotion.short),
        child: Icon(selected ? filled : outline,
            key: ValueKey(selected), size: 24, color: color),
      ),
    );
  }

  Widget _profile(BuildContext context, BuTokens t) {
    final dur = BuMotion.of(context, BuMotion.medium);
    final source = avatarUrl;
    Widget avatar(String? url) => ChatlistAvatar(
        name: avatarName ?? '',
        url: url,
        size: FloatingNav._avatar,
        circle: true);
    return AnimatedContainer(
      duration: dur,
      curve: BuMotion.decelerate,
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: selected ? t.pr : t.mut.withValues(alpha: .45),
            width: selected ? 2 : 1.25),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: t.pr.withValues(alpha: .38),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ]
            : const [],
      ),
      child: source == null
          ? avatar(null)
          : ValueListenableBuilder<String?>(
              valueListenable: source, builder: (_, url, __) => avatar(url)),
    );
  }

  Widget _withBadge(
      BuildContext context, Widget glyph, ValueNotifier<int> badge) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        glyph,
        PositionedDirectional(
          end: -12,
          top: -8,
          child: ValueListenableBuilder<int>(
            valueListenable: badge,
            builder: (_, n, __) {
              final show = n > 0 && !selected;
              return ExcludeSemantics(
                child: AnimatedScale(
                  scale: show ? 1 : 0,
                  duration: BuMotion.of(context, BuMotion.medium),
                  curve: Curves.easeOutBack,
                  child: n > 0
                      ? BuCountBadge(n, key: const ValueKey('nav-badge'))
                      : const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
