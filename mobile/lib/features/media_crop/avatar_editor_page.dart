import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/bu.dart';
import 'avatar_editor_model.dart';
import 'avatar_editor_paint.dart';
import 'crop_engine.dart';
import 'crop_spec.dart';

/// Fotoğraf düzenleyicisi (tam ekran): koyu tuval + çerçeve maskesi (profil/logo: daire; gönderi/kapak/sohbet: dikdörtgen),
/// tek parmak sürükle, iki parmak yakınlaştır / UZAKLAŞTIR (görsel çerçeveden küçülebilir; boşluk bulanık ya da düz renk
/// zeminle dolar), çift dokunma sığdır/doldur, 90° döndür + ince açı (-45..45), aynala, geri al/yinele, hazır filtreler ve
/// parlaklık/kontrast/doygunluk/sıcaklık/vinyet. [spec] verilirse çerçeve oranı ([CropSpec.aspect]) ve izin verilen
/// oranlar ([CropSpec.aspects]: "Oran" sekmesi) ile "Fotoğrafı değiştir"/"Kapağı kaldır" yan eylemleri açılır.
///
/// "Bitti" JPEG'i [CropOutcome.cropped] olarak döndürür; "İptal" null. [spec] yoksa (profil fotoğrafı) çıktı kare
/// [outputSize] x [outputSize]'tır: `pickAndCrop(CropSpec.profile)` bunu açar (profil düzenleme + kayıt sonrası fotoğraf
/// adımı). [spec] ile çıktının uzun kenarı en çok [CropSpec.maxEdge] piksel olur ve gereksiz büyütülmez.
class AvatarEditorPage extends StatefulWidget {
  const AvatarEditorPage({super.key, required this.bytes, this.outputSize = 1024, this.spec});

  final Uint8List bytes;

  /// [spec] yokken çıktı karenin kenarı (piksel).
  final int outputSize;

  /// Kullanım yeri/oran biçimi; null: profil fotoğrafı (kare, daire maske, 1024).
  final CropSpec? spec;

  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

enum _Tab { crop, ratio, bg, filter, adjust }

enum _Adj { brightness, contrast, saturation, warmth, vignette }

class _AvatarEditorPageState extends State<AvatarEditorPage> with SingleTickerProviderStateMixin {
  static const _d = BuTokens.dark;

  ui.Image? _full; // nihai çıktı için (<= ~2600 px)
  ui.Image? _preview; // tuval ve küçük önizlemeler için (<= ~1024 px): düşük cihazda akıcılık
  AvatarHistory? _hist;

  /// Çerçeve oranı ve dönüşe göre geometri (görsel yüklenene kadar null).
  AvatarGeometry? get _geo {
    final f = _full;
    return f == null ? null : AvatarGeometry.forState(f.width.toDouble(), f.height.toDouble(), _view);
  }

  /// Daire maske: profil (spec yok) ve logo gibi daire kılavuzlu türler.
  bool get _circle => widget.spec?.circle ?? true;

  /// Kullanıcının seçebileceği oranlar; boşsa oran kilitli ve "Oran" sekmesi yok.
  late final List<AvatarRatio> _ratios = () {
    final sp = widget.spec;
    final list = sp?.aspects;
    if (sp == null || sp.circle || list == null) return const <AvatarRatio>[];
    final out = <AvatarRatio>[];
    for (final a in list) {
      final r = AvatarRatio.nearest(a);
      if (!out.contains(r)) out.add(r);
    }
    return out.length > 1 ? out : const <AvatarRatio>[];
  }();

  AvatarRatio get _initialRatio {
    final sp = widget.spec;
    if (sp == null || sp.circle) return AvatarRatio.square;
    return AvatarRatio.nearest(sp.aspect);
  }
  AvatarEditState _view = const AvatarEditState();
  bool _failed = false;
  bool _busy = false;

  _Tab _tab = _Tab.crop;
  _Adj _adj = _Adj.brightness;

  bool _dragging = false;
  bool _angleDragging = false;
  bool _hitLimit = false;

  // Çimdik/sürükleme başlangıcı.
  AvatarEditState _gBase = const AvatarEditState();
  Offset _gFocal = Offset.zero;

  // Tuval yerleşimi (son derleme).
  Rect _frame = Rect.zero;

  late final AnimationController _anim = AnimationController(vsync: this);
  AvatarEditState _animFrom = const AvatarEditState();
  AvatarEditState _animTo = const AvatarEditState();

  double get _k => _frame.width / (_geo?.frameW ?? AvatarGeometry.frame);

  @override
  void initState() {
    super.initState();
    _anim.addListener(_onAnim);
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    if (_preview != null && !identical(_preview, _full)) _preview?.dispose();
    _full?.dispose();
    super.dispose();
  }

  Future<ui.Image> _decode(Uint8List b, {int? targetW, int? targetH}) async {
    final codec = await ui.instantiateImageCodec(b, targetWidth: targetW, targetHeight: targetH);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _load() async {
    try {
      var src = widget.bytes;
      if (src.length > 6 * 1024 * 1024) src = await shrinkLarge(src) ?? src; // bellek güvenliği
      var full = await _decode(src);
      const fullCap = 2600, previewCap = 1024;
      int longEdge(ui.Image i) => math.max(i.width, i.height);
      if (longEdge(full) > fullCap) {
        final wide = full.width >= full.height;
        full.dispose();
        full = await _decode(src, targetW: wide ? fullCap : null, targetH: wide ? null : fullCap);
      }
      var preview = full;
      if (longEdge(full) > previewCap) {
        final wide = full.width >= full.height;
        preview = await _decode(src, targetW: wide ? previewCap : null, targetH: wide ? null : previewCap);
      }
      if (!mounted) {
        if (!identical(preview, full)) preview.dispose();
        full.dispose();
        return;
      }
      setState(() {
        _full = full;
        _preview = preview;
        _hist = AvatarHistory(AvatarEditState(ratio: _initialRatio));
        _view = _hist!.current;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Durum + geçmiş + animasyon

  void _onAnim() {
    final t = Curves.easeOutCubic.transform(_anim.value);
    final a = _animFrom, b = _animTo;
    setState(() {
      _view = b.copyWith(
        zoom: ui.lerpDouble(a.zoom, b.zoom, t),
        fine: ui.lerpDouble(a.fine, b.fine, t),
        offset: Offset.lerp(a.offset, b.offset, t),
      );
    });
  }

  /// [target]'a yumuşakça yerleşir (azaltılmış harekette anında); sonra istenirse geçmişe işlenir.
  void _animateTo(AvatarEditState target, {bool commit = true}) {
    _anim.stop();
    final dur = AppMotion.of(context, AppMotion.emphasized);
    final from = _view;
    final structural = from.turns != target.turns || from.flip != target.flip || from.ratio != target.ratio;
    if (dur == Duration.zero || structural || from == target) {
      setState(() => _view = target);
    } else {
      _animFrom = from;
      _animTo = target;
      _anim.duration = dur;
      _anim.forward(from: 0);
    }
    if (commit) _hist!.push(target);
    setState(() {});
  }

  /// Anlık değişikliği (kaydırıcı bırakılınca vb.) geçmişe işler.
  void _commit() {
    final h = _hist;
    if (h == null) return;
    h.push(_view);
    setState(() {});
  }

  void _set(AvatarEditState s, {bool commit = true}) {
    _anim.stop();
    setState(() => _view = s);
    if (commit) _commit();
  }

  void _undo() {
    final h = _hist;
    if (h == null || !h.canUndo || _busy) return;
    BuHaptics.selection();
    _animateTo(h.undo(), commit: false);
  }

  void _redo() {
    final h = _hist;
    if (h == null || !h.canRedo || _busy) return;
    BuHaptics.selection();
    _animateTo(h.redo(), commit: false);
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Tuval hareketleri

  void _onScaleStart(ScaleStartDetails d) {
    if (_busy || _geo == null) return;
    _anim.stop();
    _gBase = _view;
    _gFocal = (d.localFocalPoint - _frame.center) / _k;
    _hitLimit = false;
    setState(() => _dragging = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final g = _geo;
    if (_busy || g == null) return;
    final base = _gBase;
    final a = g.angle(base);
    final minZ = g.minZoom(a) * .85, maxZ = AvatarGeometry.maxZoom * 1.12;
    final z = (base.zoom * d.scale).clamp(minZ, maxZ).toDouble();
    final ratio = z / base.zoom;
    final focalNow = (d.localFocalPoint - _frame.center) / _k;
    final raw = focalNow - (_gFocal - base.offset) * ratio;
    final probe = base.copyWith(zoom: z);
    final off = g.rubber(probe, raw);
    final over = off != g.clampOffset(probe, raw) || z <= g.minZoom(a) * .88 || z >= AvatarGeometry.maxZoom * 1.08;
    if (over && !_hitLimit) {
      _hitLimit = true;
      BuHaptics.light(); // sınırda hafif tık
    } else if (!over) {
      _hitLimit = false;
    }
    setState(() => _view = probe.copyWith(offset: off));
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final g = _geo;
    if (g == null) return;
    setState(() => _dragging = false);
    // Bırakınca yerleşme: sınır dışı taşma geri sarılır.
    _animateTo(g.normalize(_view));
  }

  void _onDoubleTap() {
    final g = _geo;
    if (g == null || _busy) return;
    BuHaptics.selection();
    _animateTo(g.toggledFit(_view));
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Bitti / İptal

  Future<void> _done() async {
    final full = _full, g = _geo;
    if (full == null || g == null || _busy) return;
    _anim.stop();
    final target = g.normalize(_view);
    setState(() {
      _busy = true;
      _view = target;
    });
    final sp = widget.spec;
    // Profilde sabit kare çıktı; diğerlerinde kaynak çözünürlüğü aşılmadan (en az 512) [CropSpec.maxEdge] sınırına kadar.
    final longSide = sp == null ? widget.outputSize : math.min(sp.maxEdge, math.max(512, g.nativeLongSide(target).round()));
    final out = await renderAvatarJpeg(image: full, state: target, geometry: g, size: longSide);
    if (!mounted) return;
    if (out == null) {
      setState(() => _busy = false);
      BuToast.show(context, context.l10n.p04CropError, kind: BuToastKind.error);
      return;
    }
    Navigator.of(context).pop(CropOutcome.cropped(out));
  }

  // ---------------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ready = _preview != null && _geo != null && !_failed;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: _d.bg,
        body: Column(children: [
          SafeArea(bottom: false, child: _topBar(context, l, ready)),
          Expanded(
            child: _failed
                ? _failedView(context, l)
                : !ready
                    ? const Center(child: BuSkeletonScope(child: BuSkeleton(width: 240, height: 240, radius: 120)))
                    : _stage(context, l),
          ),
          if (ready) _panel(context, l),
        ]),
      ),
    );
  }

  Widget _topBar(BuildContext context, AppLocalizations l, bool ready) {
    final tx = Theme.of(context).textTheme;
    final h = _hist;
    Widget icon(Key key, IconData ic, String label, VoidCallback? onTap, {bool mirror = false}) => IconButton(
          key: key,
          tooltip: label,
          onPressed: onTap,
          constraints: const BoxConstraints(minWidth: BuSize.touch, minHeight: BuSize.touch),
          icon: Transform.flip(flipX: mirror, child: Icon(ic, size: 22, color: onTap == null ? _d.mut.withValues(alpha: .5) : _d.ink)),
        );
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          TextButton(
            key: const ValueKey('avatarEdCancel'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: _d.ink),
            child: Text(l.avatarEdCancel, style: tx.labelLarge?.copyWith(color: _d.ink.withValues(alpha: .9), fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              icon(const ValueKey('avatarEdUndo'), BuIcons.undo2, l.avatarEdUndo, ready && h != null && h.canUndo && !_busy ? _undo : null),
              icon(const ValueKey('avatarEdRedo'), BuIcons.undo2, l.avatarEdRedo, ready && h != null && h.canRedo && !_busy ? _redo : null,
                  mirror: true),
            ]),
          ),
          Material(
            key: const ValueKey('avatarEdDone'),
            color: ready ? _d.onMedia : _d.onMedia.withValues(alpha: .4),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: ready && !_busy ? _done : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: BuSize.touch, minWidth: 88),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: _busy
                        ? SizedBox(
                            key: const ValueKey('avatarEdBusy'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: _d.scrim))
                        : Text(l.avatarEdDone, style: tx.labelLarge?.copyWith(color: _d.scrim, fontSize: 15, fontWeight: FontWeight.w400)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _failedView(BuildContext context, AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(BuIcons.imageOff, size: 36, color: _d.mut),
            const SizedBox(height: 12),
            Text(l.p04CropError,
                key: const ValueKey('cropError'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _d.ink)),
          ]),
        ),
      );

  Widget _stage(BuildContext context, AppLocalizations l) {
    final g = _geo!;
    final img = _preview!;
    return LayoutBuilder(builder: (context, box) {
      // Çerçeve, oranını koruyarak tuvale sığar.
      var w = math.max(96.0, box.maxWidth - 32);
      var h = w / g.aspect;
      final maxH = math.max(96.0, box.maxHeight - 16);
      if (h > maxH) {
        h = maxH;
        w = h * g.aspect;
      }
      _frame = Rect.fromCenter(center: Offset(box.maxWidth / 2, box.maxHeight / 2), width: w, height: h);
      return Semantics(
        container: true,
        label: l.avatarEdStageSemantic,
        child: GestureDetector(
          key: const ValueKey('avatarEdStage'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onDoubleTap: _onDoubleTap,
          child: ClipRect(
            child: Stack(fit: StackFit.expand, children: [
              CustomPaint(painter: AvatarCanvasPainter(image: img, state: _view, geometry: g, frame: _frame)),
              IgnorePointer(
                child: CustomPaint(
                  painter: AvatarMaskPainter(
                    frame: _frame,
                    circle: _circle,
                    guides: _dragging,
                    fineGrid: _angleDragging,
                    scrimColor: _d.scrim.withValues(alpha: .62),
                    lineColor: _d.onMedia,
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------------------------------------------
  // Alt panel

  Widget _panel(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final maxH = math.min(MediaQuery.sizeOf(context).height * .42, 330.0);
    return DecoratedBox(
      decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Stitch profil-v4: panel tutamacı (40 x 4).
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ExcludeSemantics(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.bd, borderRadius: BorderRadius.circular(2))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: _tabs(context, l),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: switch (_tab) {
                _Tab.crop => _cropTools(context, l),
                _Tab.ratio => _ratioTools(context, l),
                _Tab.bg => _bgTools(context, l),
                _Tab.filter => _filterTools(context, l),
                _Tab.adjust => _adjustTools(context, l),
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabs(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final items = <(_Tab, IconData, String)>[
      (_Tab.crop, BuIcons.crop, l.avatarEdTabCrop),
      if (_ratios.isNotEmpty) (_Tab.ratio, BuIcons.image, l.photoEdTabRatio),
      (_Tab.bg, BuIcons.palette, l.avatarEdTabBg),
      (_Tab.filter, BuIcons.wandSparkles, l.avatarEdTabFilter),
      (_Tab.adjust, BuIcons.slidersHorizontal, l.avatarEdTabAdjust),
    ];
    return Row(children: [
      for (final (tab, ic, label) in items)
        Expanded(
          child: Semantics(
            button: true,
            selected: _tab == tab,
            label: label,
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('avatarEdTab-${tab.name}'),
              borderRadius: BorderRadius.circular(BuRadius.md),
              onTap: () {
                if (_tab != tab) BuHaptics.selection();
                setState(() => _tab = tab);
              },
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                constraints: const BoxConstraints(minHeight: BuSize.touch + 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: _tab == tab ? t.soft : Colors.transparent,
                  borderRadius: BorderRadius.circular(BuRadius.md),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(ic, size: 20, color: _tab == tab ? t.onSoft : t.ink),
                  const SizedBox(height: 2),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tx.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: _tab == tab ? t.onSoft : t.ink)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _toolButton(BuildContext context, {required Key key, required IconData icon, required String label, required VoidCallback onTap, bool active = false}) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(BuRadius.md),
          onTap: _busy ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 22, color: active ? t.pr : t.ink),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tx.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
    required double v,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
    VoidCallback? onStart,
    VoidCallback? onEnd,
  }) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge?.copyWith(fontSize: 16, color: t.ink, fontWeight: FontWeight.w400))),
          const SizedBox(width: 8),
          Text(value, style: tx.labelLarge?.copyWith(fontSize: 16, color: t.mut, fontFeatures: const [ui.FontFeature.tabularFigures()])),
        ]),
      ),
      SizedBox(
        height: BuSize.touch,
        // Stitch profil-v4: iz panel kenar boşluğuna (16) kadar uzanır; baş 12 dp'lik kaydırıcı iç boşluğu dışarı taşırılır.
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: -14,
            right: -14,
            top: 0,
            bottom: 0,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: _RingThumbShape(ring: t.sf3),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                key: key,
                value: v.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                semanticFormatterCallback: (_) => '$label $value',
                onChangeStart: onStart == null ? null : (_) => onStart(),
                onChanged: _busy ? null : onChanged,
                onChangeEnd: onEnd == null ? null : (_) => onEnd(),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  // Kırp sekmesi -------------------------------------------------------------------------------------------------

  Widget _cropTools(BuildContext context, AppLocalizations l) {
    final g = _geo!;
    final a = g.angle(_view);
    final minZ = g.minZoom(a);
    final lnMin = math.log(minZ), lnMax = math.log(AvatarGeometry.maxZoom);
    final zv = (math.log(_view.zoom.clamp(minZ, AvatarGeometry.maxZoom)) - lnMin) / (lnMax - lnMin);
    final fine = _view.fine;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _toolButton(context, key: const ValueKey('avatarEdRotL'), icon: BuIcons.rotateCcw, label: l.avatarEdRotateLeft, onTap: () {
          BuHaptics.selection();
          _animateTo(g.rotated(_view, -1));
        }),
        _toolButton(context, key: const ValueKey('avatarEdRotR'), icon: BuIcons.rotateCw, label: l.avatarEdRotateRight, onTap: () {
          BuHaptics.selection();
          _animateTo(g.rotated(_view, 1));
        }),
        _toolButton(context, key: const ValueKey('avatarEdMirror'), icon: BuIcons.arrowLeftRight, label: l.avatarEdMirror, active: _view.flip, onTap: () {
          BuHaptics.selection();
          _animateTo(_view.copyWith(flip: !_view.flip));
        }),
        _toolButton(context, key: const ValueKey('avatarEdReset'), icon: BuIcons.refreshCcw, label: l.avatarEdReset, onTap: () {
          BuHaptics.light();
          _animateTo(_view.copyWith(turns: 0, fine: 0, flip: false, zoom: 1, offset: Offset.zero));
        }),
      ]),
      const SizedBox(height: 4),
      _sliderRow(
        context,
        key: const ValueKey('avatarEdZoom'),
        label: l.avatarEdZoom,
        value: '×${_view.zoom.toStringAsFixed(1)}',
        v: zv,
        min: 0,
        max: 1,
        onChanged: (v) => _set(g.zoomedAbout(_view, math.exp(lnMin + v * (lnMax - lnMin))), commit: false),
        onEnd: _commit,
      ),
      _sliderRow(
        context,
        key: const ValueKey('avatarEdAngle'),
        label: l.avatarEdAngle,
        value: '${fine > 0 ? '+' : ''}${fine.toStringAsFixed(fine == fine.roundToDouble() ? 0 : 1)}°',
        v: fine,
        min: -45,
        max: 45,
        divisions: 180,
        onStart: () => setState(() => _angleDragging = true),
        onChanged: (v) {
          // 0'a yakınken yapışır (hafif tık).
          final snapped = v.abs() < .6 ? 0.0 : v;
          if (snapped == 0 && fine != 0) BuHaptics.selection();
          _set(g.withFine(_view, snapped), commit: false);
        },
        onEnd: () {
          setState(() => _angleDragging = false);
          _commit();
        },
      ),
      ..._sideActions(context, l),
    ]);
  }

  /// Yan eylemler ([CropSpec.allowChange] / [CropSpec.allowRemove]): düzenleyiciyi kapatıp çağırana bildirir.
  List<Widget> _sideActions(BuildContext context, AppLocalizations l) {
    final sp = widget.spec;
    if (sp == null || (!sp.allowChange && !sp.allowRemove)) return const [];
    final t = context.bu;
    Widget link(Key key, IconData icon, String label, CropOutcome out, {bool danger = false}) => TextButton.icon(
          key: key,
          onPressed: _busy ? null : () => Navigator.of(context).pop(out),
          style: TextButton.styleFrom(
              minimumSize: const Size(BuSize.touch, BuSize.touch), foregroundColor: danger ? t.danger : t.ink),
          icon: Icon(icon, size: 18),
          label: Text(label, textAlign: TextAlign.center),
        );
    return [
      const SizedBox(height: 4),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        if (sp.allowChange) link(const ValueKey('avatarEdChange'), BuIcons.repeat, l.gonderiChangePhoto, const CropOutcome.change()),
        if (sp.allowRemove)
          link(const ValueKey('avatarEdRemove'), BuIcons.trash2, l.p04CropRemoveCover, const CropOutcome.removed(), danger: true),
      ]),
    ];
  }

  // Oran sekmesi -------------------------------------------------------------------------------------------------

  String _ratioLabel(AppLocalizations l, AvatarRatio r) => switch (r) {
        AvatarRatio.free => l.photoEdRatioFree,
        AvatarRatio.square => '1:1',
        AvatarRatio.p45 => '4:5',
        AvatarRatio.p34 => '3:4',
        AvatarRatio.w169 => '16:9',
      };

  Widget _ratioTools(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final g = _geo!;
    // Serbest: görselin kendi (döndürülmüş) oranı; rozet şekli buna göre çizilir.
    double shapeAspect(AvatarRatio r) => r.value ?? (_view.turns.isOdd ? g.imageHeight / g.imageWidth : g.imageWidth / g.imageHeight);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.photoEdRatioHint, style: tx.bodySmall?.copyWith(color: t.mut, height: 1.35)),
      const SizedBox(height: 10),
      Row(children: [
        for (final r in _ratios)
          Expanded(
            child: Semantics(
              button: true,
              selected: _view.ratio == r,
              label: _ratioLabel(l, r),
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('avatarEdRatio-${r.name}'),
                borderRadius: BorderRadius.circular(BuRadius.md),
                onTap: _busy
                    ? null
                    : () {
                        if (_view.ratio == r) return;
                        BuHaptics.selection();
                        _animateTo(_view.copyWith(ratio: r, zoom: 1, offset: Offset.zero));
                      },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 76),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: shapeAspect(r).clamp(.4, 2.5).toDouble(),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _view.ratio == r ? t.soft : Colors.transparent,
                              border: Border.all(color: _view.ratio == r ? t.pr : t.bdStrong, width: _view.ratio == r ? 2.5 : 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_ratioLabel(l, r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: r == AvatarRatio.free ? null : TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: tx.labelMedium?.copyWith(
                            fontSize: 12, fontWeight: _view.ratio == r ? FontWeight.w400 : FontWeight.w500, color: t.ink)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }

  // Zemin sekmesi ------------------------------------------------------------------------------------------------

  String _bgLabel(AppLocalizations l, AvatarBg b) => switch (b) {
        AvatarBg.blur => l.avatarEdBgBlur,
        AvatarBg.white => l.avatarEdBgWhite,
        AvatarBg.black => l.avatarEdBgBlack,
        AvatarBg.brand => l.avatarEdBgBrand,
        AvatarBg.navy => l.avatarEdBgNavy,
        AvatarBg.sand => l.avatarEdBgSand,
      };

  Widget _bgTools(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.avatarEdBgHint, style: tx.bodySmall?.copyWith(color: t.mut, height: 1.35)),
      const SizedBox(height: 10),
      Row(children: [
        for (final b in AvatarBg.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: _view.bg == b,
              label: _bgLabel(l, b),
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('avatarEdBg-${b.name}'),
                borderRadius: BorderRadius.circular(BuRadius.md),
                onTap: _busy
                    ? null
                    : () {
                        if (_view.bg != b) BuHaptics.selection();
                        _set(_view.copyWith(bg: b));
                      },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 76),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _view.bg == b ? t.pr : t.bdStrong, width: _view.bg == b ? 3 : 1),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(child: _bgSwatch(b)),
                    ),
                    const SizedBox(height: 4),
                    Text(_bgLabel(l, b),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: tx.labelMedium?.copyWith(fontSize: 11, fontWeight: _view.bg == b ? FontWeight.w400 : FontWeight.w500, color: t.ink)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _bgSwatch(AvatarBg b) {
    final c = avatarBgColor(b);
    if (c != null) return ColoredBox(color: c);
    final img = _preview;
    if (img == null) return const SizedBox.shrink();
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: TileMode.clamp),
      child: SizedBox.expand(child: RawImage(image: img, fit: BoxFit.cover)),
    );
  }

  // Filtre sekmesi -----------------------------------------------------------------------------------------------

  String _filterLabel(AppLocalizations l, AvatarFilter f) => switch (f) {
        AvatarFilter.original => l.avatarEdFOriginal,
        AvatarFilter.vivid => l.avatarEdFVivid,
        AvatarFilter.cool => l.avatarEdFCool,
        AvatarFilter.warm => l.avatarEdFWarm,
        AvatarFilter.mono => l.avatarEdFMono,
        AvatarFilter.faded => l.avatarEdFFaded,
      };

  Widget _filterTools(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final img = _preview!;
    return SizedBox(
      height: 136,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AvatarFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final f = AvatarFilter.values[i];
          final sel = _view.filter == f;
          return Semantics(
            button: true,
            selected: sel,
            label: _filterLabel(l, f),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('avatarEdFilter-${f.name}'),
              borderRadius: BorderRadius.circular(BuRadius.md),
              onTap: _busy
                  ? null
                  : () {
                      if (!sel) BuHaptics.selection();
                      _set(_view.copyWith(filter: f));
                    },
              child: SizedBox(
                width: 76,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(BuRadius.md),
                      border: Border.all(color: sel ? t.pr : t.bd, width: sel ? 3 : 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(BuRadius.sm),
                      child: SizedBox.expand(
                        child: ColorFiltered(
                          colorFilter: ColorFilter.matrix(filterMatrix(f)),
                          child: RawImage(image: img, fit: BoxFit.cover, filterQuality: FilterQuality.low),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_filterLabel(l, f),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: tx.labelMedium?.copyWith(fontSize: 12, fontWeight: sel ? FontWeight.w400 : FontWeight.w500, color: sel ? t.prPressed : t.ink)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // Ayarla sekmesi -----------------------------------------------------------------------------------------------

  String _adjLabel(AppLocalizations l, _Adj a) => switch (a) {
        _Adj.brightness => l.avatarEdBrightness,
        _Adj.contrast => l.avatarEdContrast,
        _Adj.saturation => l.avatarEdSaturation,
        _Adj.warmth => l.avatarEdWarmth,
        _Adj.vignette => l.avatarEdVignette,
      };

  double _adjValue(_Adj a) => switch (a) {
        _Adj.brightness => _view.adjust.brightness,
        _Adj.contrast => _view.adjust.contrast,
        _Adj.saturation => _view.adjust.saturation,
        _Adj.warmth => _view.adjust.warmth,
        _Adj.vignette => _view.adjust.vignette,
      };

  AvatarAdjust _withAdj(_Adj a, double v) => switch (a) {
        _Adj.brightness => _view.adjust.copyWith(brightness: v),
        _Adj.contrast => _view.adjust.copyWith(contrast: v),
        _Adj.saturation => _view.adjust.copyWith(saturation: v),
        _Adj.warmth => _view.adjust.copyWith(warmth: v),
        _Adj.vignette => _view.adjust.copyWith(vignette: v),
      };

  Widget _adjustTools(BuildContext context, AppLocalizations l) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final v = _adjValue(_adj);
    final isVig = _adj == _Adj.vignette;
    final changed = _view.adjust != const AvatarAdjust();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _Adj.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final a = _Adj.values[i];
            final sel = a == _adj;
            final touched = _adjValue(a) != 0;
            return Semantics(
              button: true,
              selected: sel,
              label: _adjLabel(l, a),
              excludeSemantics: true,
              child: Material(
                color: sel ? t.soft : t.sf2,
                shape: StadiumBorder(side: sel ? BorderSide(color: t.selectedBorder) : BorderSide.none),
                child: InkWell(
                  key: ValueKey('avatarEdAdj-${a.name}'),
                  customBorder: const StadiumBorder(),
                  onTap: () => setState(() => _adj = a),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_adjLabel(l, a), style: tx.labelLarge?.copyWith(color: sel ? t.onSoft : t.ink, fontWeight: FontWeight.w400)),
                        if (touched) ...[
                          const SizedBox(width: 6),
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle)),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      _sliderRow(
        context,
        key: const ValueKey('avatarEdAdjSlider'),
        label: _adjLabel(l, _adj),
        value: '${(v * 100).round()}',
        v: v,
        min: isVig ? 0 : -1,
        max: 1,
        divisions: isVig ? 50 : 100,
        onChanged: (x) => _set(_view.copyWith(adjust: _withAdj(_adj, x)), commit: false),
        onEnd: _commit,
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton(
          key: const ValueKey('avatarEdAdjReset'),
          onPressed: changed && !_busy
              ? () {
                  BuHaptics.light();
                  _set(_view.copyWith(adjust: const AvatarAdjust()));
                }
              : null,
          style: TextButton.styleFrom(minimumSize: const Size(BuSize.touch, BuSize.touch)),
          child: Text(l.avatarEdReset),
        ),
      ),
    ]);
  }
}

/// Stitch profil-v4 kaydırıcı tutamacı: 11 dp dolu daire + 3 dp açık halka (gölgesiz).
class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape({required this.ring});

  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final c = context.canvas;
    c.drawCircle(center, 14, Paint()..color = ring);
    c.drawCircle(center, 11, Paint()..color = sliderTheme.thumbColor ?? ring);
  }
}
