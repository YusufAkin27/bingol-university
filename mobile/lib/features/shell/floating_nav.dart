import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/motion/bu_count_up.dart' show BuPop;
import '../../core/theme.dart';
import '../../core/theme/bu_motion.dart';
import '../../core/theme/bu_sizes.dart';
import '../../widgets/bu_glass.dart';
import '../../widgets/bu_list.dart' show BuCountBadge;
import '../../widgets/bu_pressable.dart' show BuHaptic, BuPressable, buHaptic;
import '../chat/chatlist_widgets.dart' show ChatlistAvatar;
import '../../core/icons/bu_icons.dart';

/// Yüzen alt gezinme (PREMIUM MONOCHROME + LIQUID GLASS): kenarlardan ve alttan 16 dp boşluklu, 64 dp yüksekliğinde hap.
/// Beş öğe: Ana Sayfa, Keşfet, ortada "+" (Paylaş: `pr` daire = koyuda beyaz zemin + siyah artı, açıkta tersi; çubuktan
/// yukarı taşar), Sohbet (okunmamış rozeti), Profil (avatar).
///
/// **Malzeme (iOS 26 Liquid Glass):** yüzey arkasındaki içeriği bulanıklaştırıp canlandırır (`BackdropFilter`, sigma 22,
/// doygunluk 1.45), yarı saydam nötr dolgu + kenar kırılması (iç parıltı, üst spekular şerit, köşegen rim) + yalnız dışa
/// düşen yumuşak gölge çizer (`lib/widgets/bu_glass.dart`). Seçili sekme, çubuğun içinde kayan daha açık bir cam
/// KAPSÜL'dür: sekmeler arasında yay benzeri eğriyle akar (hafif aşım), basılı tutulunca/sürüklenince esner (1.14 x 1.08)
/// ve sürükleme bırakılınca en yakın sekmeyi seçer. Aktif simge `ink` (dolu), pasif simge `ink` %62-70 (çizgi); etiket
/// görünmez (ekran okuyucu için var).
///
/// **Yedek:** "animasyonları azalt", "yüksek karşıtlık" ya da `glass: false` iken bulanıklık/rim YOK: önceki opak `sf`
/// yüzey + ince `bd` kenarlık. Klavye açılınca çubuk gizlenir. Tam ekran videoda (`immersive`) koyu cam malzeme + açık
/// simgeler kullanılır. İçerik kaydırılırken çubuk sabit kalır.
///
/// Sınıf adı ve zorunlu parametreler eski gezinmeyle aynıdır (kabuk ve testler değişmeden kullanır). Erişilebilirlik: her
/// sekme tek düğüm ("Sohbet, 3 okunmamış", seçili durumu, "Tab 3 of 5"). Yazı ölçeği etiketlerde en çok 1.15'e sınırlanır.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.chatBadge,
    this.avatarUrl,
    this.avatarName,
    this.onPublish,
    this.immersive = false,
    this.glass = true,
  });

  final VoidCallback? onPublish;

  /// Tam ekran video (Reels) üstünde: koyu cam malzeme, simgeler açık renk olur; video engellenmez. Geçiş 180 ms.
  final bool immersive;

  /// Cam malzeme açık mı (false: opak yedek; performans/erişilebilirlik anahtarı).
  final bool glass;

  final int index;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;

  /// Profil sekmesi avatarının fotoğraf adresi (yok/null: varsayılan profil görseli).
  final ValueListenable<String?>? avatarUrl;

  /// Varsayılan görselin renk varyantı için ad (aynı kişi her yerde aynı rengi alır).
  final String? avatarName;

  /// Çubuğun nominal içerik yüksekliği.
  static const double height = BuSize.nav;

  /// Çubuğun kenarlardan ve alttan dış boşluğu.
  static const double gap = BuSize.navGap;

  /// "+" dairesinin çubuğun üstüne taşan kısmı için ayrılan şeffaf pay (dokunma alanı içinde kalsın).
  static const double lift = 12;

  static const double _hPad = 6; // çubuk iç yan boşluğu
  static const double _plusSlot = 48; // "+" hücresi
  static const double _plusSize = 52; // "+" dairesi çapı
  static const double _plusRise = 10; // dairenin çubuktan yukarı taşması
  static const double _icon = 22;
  static const double _avatar = 22; // avatar çapı (halka dışı)
  static const double _capsuleH = 46; // seçili sekme kapsülü yüksekliği

  static const _outline = [BuIcons.home, BuIcons.discover, BuIcons.chat, BuIcons.users];
  static const _filled = [BuIcons.homeFilled, BuIcons.discoverFilled, BuIcons.chatFilled, BuIcons.usersFilled];

  static List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.navHome, l.navDiscover, l.navChat, l.navClubs, l.navProfile];
  }

  /// Cam yerine opak yüzey kullanılmalı mı: kapalı anahtar, "animasyonları azalt" ya da yüksek karşıtlık.
  static bool opaqueFallback(BuildContext context, {bool glass = true}) {
    final mq = MediaQuery.maybeOf(context);
    return !glass || (mq?.disableAnimations ?? false) || (mq?.highContrast ?? false);
  }

  @override
  Widget build(BuildContext context) {
    // Klavye açıkken çubuk yüzmez: yumuşakça kapanır (içerik alanı genişler).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnimatedSize(
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.standard,
      alignment: Alignment.bottomCenter,
      child: keyboard ? const SizedBox(width: double.infinity) : _bar(context),
    );
  }

  Widget _bar(BuildContext context) {
    final t = context.bu;
    final opaque = opaqueFallback(context, glass: glass);
    // Koyu malzeme: koyu tema ya da tam ekran video üstü.
    final dark = immersive || Theme.of(context).brightness == Brightness.dark;
    final slots = onPublish == null ? const [0, 1, 2, 3, 4] : const [0, 1, -1, 2, 4];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: gap),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(gap, 0, gap, 0),
        child: SizedBox(
          height: height + lift,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Cam yüzey: yalnız çubuğun kendisi (taşan "+" bunun dışında, üst katmanda).
              Positioned(
                top: lift,
                left: 0,
                right: 0,
                bottom: 0,
                child: BuGlassBar(
                  key: const ValueKey('nav-pill'),
                  dark: dark,
                  white: t.onMedia,
                  base: t.bg,
                  ink: t.ink,
                  opaque: opaque,
                  opaqueColor: immersive ? Colors.transparent : t.sf,
                  opaqueBorder: immersive ? Colors.transparent : t.bd,
                ),
              ),
              Positioned.fill(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.15,
                  child: _NavRow(
                    index: index,
                    slots: slots,
                    labels: _labels(context),
                    onChanged: onChanged,
                    onPublish: onPublish,
                    chatBadge: chatBadge,
                    avatarUrl: avatarUrl,
                    avatarName: avatarName,
                    immersive: immersive,
                    dark: dark,
                    opaque: opaque,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _chatIndex = 2; // AppTab.chat (döngüsel içe aktarmayı önlemek için)

/// Kapsülün sekmeler arasındaki kayışı: yay benzeri, hafif aşımlı eğri (iOS 26 sıvı kayma hissi).
const Curve _glide = Cubic(0.25, 1.28, 0.42, 1.0);
const Duration _glideDuration = Duration(milliseconds: 360);

/// Hücre yerleşimi: her slotun başlangıcı ve genişliği.
class _NavGeometry {
  _NavGeometry(double inner, List<int> slots) {
    final hasPlus = slots.contains(-1);
    final tabs = slots.where((i) => i >= 0).length;
    final remaining = inner - (hasPlus ? FloatingNav._plusSlot : 0);
    // Etiket yok: tüm sekme hücreleri eşit genişlikte; seçili sekme cam kapsülle belli olur.
    tabW = remaining / tabs;
    var x = 0.0;
    for (final i in slots) {
      final w = i == -1 ? FloatingNav._plusSlot : tabW;
      lefts.add(x);
      widths.add(w);
      x += w;
    }
  }

  late final double tabW;
  final lefts = <double>[];
  final widths = <double>[];
}

/// Hücreleri ve kayan cam kapsülü yerleştirir; sürükleme/basılı tutma kapsülü esnetir.
class _NavRow extends StatefulWidget {
  const _NavRow({
    required this.index,
    required this.slots,
    required this.labels,
    required this.onChanged,
    required this.chatBadge,
    required this.dark,
    required this.opaque,
    this.onPublish,
    this.avatarUrl,
    this.avatarName,
    this.immersive = false,
  });

  final bool immersive;
  final bool dark;
  final bool opaque;
  final int index;
  final List<int> slots;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final ValueNotifier<int> chatBadge;
  final VoidCallback? onPublish;
  final ValueListenable<String?>? avatarUrl;
  final String? avatarName;

  @override
  State<_NavRow> createState() => _NavRowState();
}

class _NavRowState extends State<_NavRow> {
  // Son yerleşim (hareket işleyicileri için; start-koordinatı = yazı yönünde soldan/sağdan uzaklık).
  final Map<int, double> _centers = {};
  double _maxW = 0;
  double _plusStart = -1;
  bool _rtl = false;

  bool _down = false; // parmak çubuk üstünde (Paylaş hariç)
  double? _dragCenter; // sürüklenen kapsülün merkezi
  int? _hover; // sürüklerken en yakın sekme

  bool get _dragging => _dragCenter != null;

  void _setDown(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  int _nearest(double c) {
    var best = widget.index;
    var d = double.infinity;
    _centers.forEach((tab, x) {
      final dd = (x - c).abs();
      if (dd < d) {
        d = dd;
        best = tab;
      }
    });
    return best;
  }

  /// Parmağın yazı yönündeki (start) konumu; kapsül parmağı mutlak olarak izler (iOS 26 gibi).
  double _finger(Offset local) => _rtl ? _maxW - local.dx : local.dx;

  double _clampCenter(double x) {
    final lo = _centers.values.reduce((a, b) => a < b ? a : b);
    final hi = _centers.values.reduce((a, b) => a > b ? a : b);
    return x.clamp(lo, hi);
  }

  void _dragStart(DragStartDetails d) {
    if (_centers.isEmpty || !_centers.containsKey(widget.index)) return;
    final c = _clampCenter(_finger(d.localPosition));
    setState(() {
      _dragCenter = c;
      _hover = _nearest(c);
    });
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_dragCenter == null) return;
    final next = _clampCenter(_finger(d.localPosition));
    final near = _nearest(next);
    if (near != _hover) buHaptic(BuHaptic.selection);
    setState(() {
      _dragCenter = next;
      _hover = near;
    });
  }

  void _dragEnd([DragEndDetails? _]) {
    final pick = _hover;
    setState(() {
      _dragCenter = null;
      _hover = null;
      _down = false;
    });
    if (pick != null && pick != widget.index) widget.onChanged(pick);
  }

  void _dragCancel() {
    if (!_dragging && !_down) return;
    setState(() {
      _dragCenter = null;
      _hover = null;
      _down = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final reduced = BuMotion.reduced(context);
    final dur = AppMotion.of(context, AppMotion.normal);
    final slots = widget.slots;
    _rtl = Directionality.of(context) == TextDirection.rtl;
    // Simge renkleri: cam üstünde pasif simge `ink` %62-70 (WCAG: arka plan değişse de >= 3:1); opak yedekte `mut`.
    final fg = widget.immersive ? t.onMedia : t.ink;
    final passive = widget.opaque
        ? (widget.immersive ? t.onMedia.withValues(alpha: .8) : t.mut)
        : fg.withValues(alpha: widget.dark ? .78 : .64);
    final lit = _hover ?? widget.index;
    return LayoutBuilder(builder: (context, c) {
      final geo = _NavGeometry(c.maxWidth - 2 * FloatingNav._hPad, slots);
      const top = FloatingNav.lift;
      _maxW = c.maxWidth;
      _centers.clear();
      for (var pos = 0; pos < slots.length; pos++) {
        if (slots[pos] == -1) {
          _plusStart = FloatingNav._hPad + geo.lefts[pos];
        } else {
          _centers[slots[pos]] = FloatingNav._hPad + geo.lefts[pos] + geo.widths[pos] / 2;
        }
      }
      Widget cell(int pos, Widget child) => AnimatedPositionedDirectional(
            duration: dur,
            curve: AppMotion.standard,
            start: FloatingNav._hPad + geo.lefts[pos],
            width: geo.widths[pos],
            top: top,
            height: FloatingNav.height,
            child: child,
          );

      // Kapsül: seçili sekmenin hücresine kayar; sürüklerken parmağı izler (anında), bırakınca en yakın sekmeye akar.
      final capW = (geo.tabW - 8).clamp(40.0, 64.0);
      final center = _dragCenter ?? _centers[widget.index];
      final stretch = !reduced && (_down || _dragging);
      Widget? capsule;
      if (center != null && !widget.opaque) {
        capsule = AnimatedPositionedDirectional(
          duration: _dragging || reduced ? Duration.zero : _glideDuration,
          curve: _glide,
          start: center - capW / 2,
          width: capW,
          top: top + (FloatingNav.height - FloatingNav._capsuleH) / 2,
          height: FloatingNav._capsuleH,
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: stretch ? 1 : 0),
              duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(1 + .14 * v, 1 + .08 * v, 1),
                child: BuGlassCapsule(
                  key: const ValueKey('nav-indicator'),
                  dark: widget.dark,
                  white: t.onMedia,
                  base: t.bg,
                  ink: t.ink,
                  energy: v.clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
        );
      }
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          final sx = _rtl ? _maxW - e.localPosition.dx : e.localPosition.dx;
          final onPlus = widget.onPublish != null && sx >= _plusStart && sx <= _plusStart + FloatingNav._plusSlot;
          if (!onPlus) _setDown(true);
        },
        onPointerUp: (_) {
          if (!_dragging) _setDown(false);
        },
        onPointerCancel: (_) => _dragCancel(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _dragStart,
          onHorizontalDragUpdate: _dragUpdate,
          onHorizontalDragEnd: _dragEnd,
          onHorizontalDragCancel: _dragCancel,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (capsule != null) capsule,
              for (var pos = 0; pos < slots.length; pos++)
                if (slots[pos] == -1)
                  AnimatedPositionedDirectional(
                    duration: dur,
                    curve: AppMotion.standard,
                    start: FloatingNav._hPad + geo.lefts[pos] + (FloatingNav._plusSlot - FloatingNav._plusSize) / 2,
                    width: FloatingNav._plusSize,
                    top: top - FloatingNav._plusRise,
                    height: FloatingNav._plusSize,
                    child: _PlusButton(onPublish: widget.onPublish, glass: !widget.opaque),
                  )
                else
                  cell(
                    pos,
                    _NavItem(
                      key: ValueKey('nav-${slots[pos]}'),
                      position: pos,
                      selected: slots[pos] == widget.index,
                      lit: slots[pos] == lit,
                      label: widget.labels[slots[pos]],
                      onTap: () {
                        if (slots[pos] != widget.index) buHaptic(BuHaptic.selection);
                        widget.onChanged(slots[pos]);
                      },
                      outline: slots[pos] < 4 ? FloatingNav._outline[slots[pos]] : (widget.onPublish == null ? null : BuIcons.user),
                      filled: slots[pos] < 4 ? FloatingNav._filled[slots[pos]] : null,
                      badge: slots[pos] == _chatIndex ? widget.chatBadge : null,
                      avatarUrl: slots[pos] == 4 ? widget.avatarUrl : null,
                      avatarName: widget.avatarName,
                      active: fg,
                      passive: passive,
                    ),
                  ),
            ],
          ),
        ),
      );
    });
  }
}

/// Ortadaki "+" düğmesi: `pr` daire; basınca 80 ms'de 0.94'e küçülür, bırakınca 140 ms'de döner.
/// Cam çubuk üstünde okunur kalması için ince `bg` halka + yumuşak gölge taşır (opak yedekte eski 3 dp `bg` halka).
class _PlusButton extends StatefulWidget {
  const _PlusButton({this.onPublish, this.glass = false});

  final VoidCallback? onPublish;
  final bool glass;

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final pressed = _down && !BuMotion.reduced(context);
    return Semantics(
      button: true,
      label: l.discoverCompose,
      onTap: widget.onPublish,
      child: Tooltip(
        message: l.discoverCompose,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => _set(true),
            onPointerUp: (_) => _set(false),
            onPointerCancel: (_) => _set(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPublish,
              child: AnimatedScale(
                scale: pressed ? .94 : 1,
                duration: pressed ? AppMotion.instant : AppMotion.fast,
                curve: AppMotion.standard,
                child: DecoratedBox(
                  key: const ValueKey('nav-publish'),
                  // Paylaş: koyuda beyaz zemin + siyah artı, açıkta siyah zemin + beyaz artı (`pr`/`onPr`).
                  decoration: BoxDecoration(
                    color: t.pr,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.glass ? t.bg.withValues(alpha: .55) : t.bg, width: widget.glass ? 2 : 3),
                    boxShadow: widget.glass
                        ? [BoxShadow(color: t.shadow.withValues(alpha: .20), blurRadius: 12, offset: const Offset(0, 4))]
                        : const <BoxShadow>[],
                  ),
                  child: Center(child: Icon(BuIcons.plus, size: 26, color: t.onPr)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek sekme: simge (Profil'de avatar); tüm hücre dokunma alanıdır (en az 44 x 64 dp).
class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.position,
    required this.selected,
    required this.lit,
    required this.label,
    required this.onTap,
    required this.active,
    required this.passive,
    this.outline,
    this.filled,
    this.badge,
    this.avatarUrl,
    this.avatarName,
  });

  final int position;

  /// Gerçek seçili sekme (ekran okuyucu + rozet gizleme).
  final bool selected;

  /// Görsel olarak vurgulu (sürüklerken kapsülün altındaki sekme; aksi halde [selected] ile aynı).
  final bool lit;
  final String label;

  final VoidCallback onTap;
  final Color active;
  final Color passive;
  final IconData? outline;
  final IconData? filled;
  final ValueNotifier<int>? badge;
  final ValueListenable<String?>? avatarUrl;
  final String? avatarName;

  bool get _isProfile => outline == null || filled == null;

  @override
  Widget build(BuildContext context) {
    final color = lit ? active : passive;
    final unread = badge;
    Widget glyph = _isProfile ? _profile(context) : _icon(context, color);
    if (unread != null) glyph = _withBadge(context, glyph, unread);
    // Etiket GÖRÜNMEZ (yalnız ekran okuyucu için `label`): seçili sekme cam kapsül + dolu simge ile ayırt edilir.
    final visual = ExcludeSemantics(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: glyph,
        ),
      ),
    );
    final tab = MaterialLocalizations.of(context).tabLabel(tabIndex: position + 1, tabCount: 5);
    final Widget item = BuPressable(onTap: onTap, scale: .95, child: visual);
    // Ekran okuyucu: tek düğüm; rozet metni sekme etiketine eklenir ("Sohbet, 3 okunmamış").
    if (unread != null) {
      return ValueListenableBuilder<int>(
        valueListenable: unread,
        builder: (c, n, _) => _semantic(
          n > 0 && !selected ? '$label, ${c.l10n.p18NavUnread(n > 99 ? '99+' : '$n')}' : label,
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
    return _IconPop(
      selected: lit,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.fast),
        child: Icon(lit ? filled : outline, key: ValueKey(lit), size: FloatingNav._icon, color: color),
      ),
    );
  }

  Widget _profile(BuildContext context) {
    final dur = AppMotion.of(context, AppMotion.fast);
    final source = avatarUrl;
    Widget avatar(String? url) => ChatlistAvatar(name: avatarName ?? '', url: url, size: FloatingNav._avatar, circle: true);
    return _IconPop(
      selected: lit,
      child: AnimatedContainer(
        duration: dur,
        curve: AppMotion.standard,
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: lit ? active : passive.withValues(alpha: .75), width: lit ? 2 : 1.25),
        ),
        child: source == null
            ? avatar(null)
            : ValueListenableBuilder<String?>(valueListenable: source, builder: (_, url, __) => avatar(url)),
      ),
    );
  }

  Widget _withBadge(BuildContext context, Widget glyph, ValueNotifier<int> badge) {
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
                  duration: AppMotion.of(context, AppMotion.fast),
                  curve: Curves.easeOutBack,
                  child: n > 0 ? BuPop(trigger: n, child: BuCountBadge(n, key: const ValueKey('nav-badge'))) : const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Seçilince ölçek 1.0 -> 1.08 -> 1.0 (220 ms); seçimden çıkınca ya da "animasyonları azalt" açıkken oynamaz.
class _IconPop extends StatefulWidget {
  const _IconPop({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  State<_IconPop> createState() => _IconPopState();
}

class _IconPopState extends State<_IconPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.normal);
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08).chain(CurveTween(curve: AppMotion.enter)), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: AppMotion.standard)), weight: 50),
  ]);

  @override
  void didUpdateWidget(_IconPop old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !BuMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale.animate(_c), child: widget.child);
}
