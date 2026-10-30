import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';

/// Sohbet yardımcı ekranları (bilgi, yeni sohbet, rehber, ilet, kamera): ortak tasarım bileşenleri.
/// Dış imzalar P6/P9/P7 tarafından kullanılır ve KİLİTLİDİR; görünüm P0 tasarım sistemine (M3 + BuTokens) taşındı.

/// Eski sabit gölge (avatar halkası vb.). Yeni kod [BuElevation.of] kullanır.
const sohbetyShadow = [
  BoxShadow(color: Color(0x40171E33), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -12),
];

/// Büyük harf etiketler ("MEDYA · 24"); Türkçede i/ı doğru büyütülür.
String sohbetyUpper(BuildContext context, String s) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (lang == 'tr') {
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return s.toUpperCase();
}

bool _ar(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ar';

/// Üst başlık: 48 dp geri düğmesi + başlık (headlineSmall).
class SohbetyHeader extends StatelessWidget {
  const SohbetyHeader({super.key, required this.title, required this.onBack, this.trailing});

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, MediaQuery.paddingOf(context).top + 12, 16, 12),
      child: Row(children: [
        BuIconButton(icon: LucideIcons.arrowLeft, onTap: onBack, tooltip: context.l10n.commonBack),
        BuGap.w12,
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: t.ink)),
          ),
        ),
        if (trailing != null) ...[BuGap.w8, trailing!],
      ]),
    );
  }
}

/// Kart: 20 dp köşe, ince çizgi, hafif yükselti. Satırlar arasına çizgi koyar.
class SohbetyCard extends StatelessWidget {
  const SohbetyCard({super.key, required this.children, this.dividers = true});

  final List<Widget> children;
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BuRadius.bLg,
        border: Border.all(color: t.bd),
        boxShadow: BuElevation.of(context, 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0 && dividers) Divider(height: 1, thickness: 1, color: t.bd),
          children[i],
        ],
      ]),
    );
  }
}

/// Kart içi satır: en az [minHeight] yüksek, 16 dp yan boşluk, dalga efektli.
class SohbetyRow extends StatelessWidget {
  const SohbetyRow(
      {super.key,
      required this.child,
      this.onTap,
      this.minHeight = 56,
      this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 6)});

  final Widget child;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(padding: padding, child: Align(alignment: AlignmentDirectional.centerStart, child: child)),
      ),
    );
  }
}

/// Simge karosu: marka tonu (tehlike: kırmızı ton); [filled] dolu marka rengi + beyaz simge (yeni grup).
class SohbetyTile extends StatelessWidget {
  const SohbetyTile({super.key, required this.icon, this.danger = false, this.size = 36, this.filled = false});

  final IconData icon;
  final bool danger;
  final double size;

  /// Dolu kırmızı zemin + beyaz simge (yeni grup).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final bg = filled ? t.pr : (danger ? t.danger.withValues(alpha: .12) : t.soft);
    final fg = filled ? t.onPr : (danger ? t.danger : t.onSoft);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size > 36 ? 14 : 12)),
        child: Icon(icon, size: size > 36 ? 20 : 18, color: fg),
      ),
    );
  }
}

/// Satırın iki satırlı metni: kalın ad + soluk alt satır.
class SohbetyTexts extends StatelessWidget {
  const SohbetyTexts({super.key, required this.title, this.sub, this.color, this.weight = FontWeight.w700});

  final String title;
  final String? sub;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tx.titleMedium!.copyWith(fontWeight: weight, color: color ?? t.ink)),
        if (sub != null && sub!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tx.bodyMedium!.copyWith(color: t.mut)),
          ),
      ],
    );
  }
}

/// Bölüm etiketi: labelMedium, geniş harf aralığı (Arapçada 0), soluk.
class SohbetyLabel extends StatelessWidget {
  const SohbetyLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .copyWith(fontWeight: FontWeight.w700, letterSpacing: _ar(context) ? 0 : .72, color: context.bu.mut)),
    );
  }
}

/// Arama / yazı alanı: 56 (ya da 48) dp, 16 dp köşe; odaklanınca marka halkası.
class SohbetyField extends StatefulWidget {
  const SohbetyField(
      {super.key, required this.hint, this.controller, this.onChanged, this.autofocus = false, this.height = 56});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final double height;

  @override
  State<SohbetyField> createState() => _SohbetyFieldState();
}

class _SohbetyFieldState extends State<SohbetyField> {
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Focus(
      onFocusChange: (v) => setState(() => _focus = v),
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        height: widget.height,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BuRadius.bMd,
          border: Border.all(color: _focus ? t.pr : t.bd, width: _focus ? 2 : 1),
        ),
        child: Row(children: [
          Icon(LucideIcons.search, size: widget.height > 50 ? 20 : 18, color: _focus ? t.pr : t.mut),
          BuGap.w12,
          Expanded(
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              cursorColor: t.pr,
              style: tx.bodyLarge!.copyWith(color: t.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: widget.hint,
                hintStyle: tx.bodyLarge!.copyWith(color: t.mut),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Fotoğrafsız avatar: marka tonu zemin + baş harf(ler); fotoğraf varsa yuvarlak görsel.
class SohbetyAvatar extends StatelessWidget {
  const SohbetyAvatar({super.key, required this.name, this.url, this.size = 48, this.headers, this.ring = false});

  final String name;
  final String? url;
  final double size;
  final Map<String, String>? headers;

  /// Beyaz halka + gölge (sohbet bilgisi büyük avatarı).
  final bool ring;

  static String initial(String name) {
    final s = name.trim();
    if (s.isEmpty) return '?';
    return String.fromCharCode(s.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final has = url != null && url!.isNotEmpty;
    final Widget inner = has
        ? BuAvatar(name: name, url: url, size: size, headers: headers)
        : ExcludeSemantics(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
              child: Text(initial(name),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontSize: size * .38, fontWeight: FontWeight.w800, color: t.onSoft)),
            ),
          );
    if (!(ring && has)) return inner;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: t.sf, width: 3),
        boxShadow: BuElevation.of(context, 2),
      ),
      child: inner,
    );
  }
}

/// Tam genişlikli ana düğme (P0 [BuButton]: 54 dp, basınca küçülme + titreşim, meşgulken düğme içi çember).
class SohbetyButton extends StatelessWidget {
  const SohbetyButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: double.infinity, child: BuButton(label: label, onPressed: onPressed, busy: busy));
}

/// Seçim işareti: seçiliyken marka dolu daire + onay (yumuşak geçiş), değilken 2 dp çizgili boş daire.
class SohbetyCheck extends StatelessWidget {
  const SohbetyCheck({super.key, required this.on, this.size = 26});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: BuMotion.of(context, BuMotion.short),
        curve: BuMotion.standard,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? t.pr : t.pr.withValues(alpha: 0),
          border: Border.all(color: on ? t.pr : t.bd, width: 2),
        ),
        child: AnimatedScale(
          scale: on ? 1 : .4,
          duration: BuMotion.of(context, BuMotion.short),
          curve: BuMotion.emphasizedDecelerate,
          child: AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: BuMotion.of(context, BuMotion.short),
            child: Icon(LucideIcons.check, size: 16, color: t.onPr),
          ),
        ),
      ),
    );
  }
}

/// Sekme denetimi (segment): ikincil zemin, seçili sekme marka tonu; 48 dp yüksek.
class SohbetyTabs extends StatelessWidget {
  const SohbetyTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bPill),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) BuGap.w4,
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (i != selected) buHaptic();
                    onSelect(i);
                  },
                  child: AnimatedContainer(
                    duration: BuMotion.of(context, BuMotion.short),
                    curve: BuMotion.standard,
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == selected ? t.soft : t.soft.withValues(alpha: 0),
                      borderRadius: BuRadius.bPill,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(labels[i],
                          maxLines: 1,
                          softWrap: false,
                          style: tx.labelLarge!
                              .copyWith(fontWeight: FontWeight.w700, color: i == selected ? t.onSoft : t.mut)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Kamera ekranı (koyu): kapat / flaş (ya da kayıt sayacı), odak çerçevesi, ipucu, galeri / deklanşör / çevir.
/// Önizleme arkada sayfa tarafından çizilir; bu katman yalnız denetimleri taşır (Stitch 25: kamera + kayıt durumu).
class SohbetyCameraChrome extends StatelessWidget {
  const SohbetyCameraChrome({
    super.key,
    required this.recording,
    required this.timer,
    required this.flashOn,
    required this.onClose,
    required this.onFlash,
    required this.onGallery,
    required this.onFlip,
    required this.onPhoto,
    required this.onVideoStart,
    required this.onVideoEnd,
    required this.closeLabel,
    required this.flashLabel,
    required this.galleryLabel,
    required this.flipLabel,
    required this.shutterLabel,
    required this.hint,
    this.progress = 0,
    this.galleryThumb,
  });

  final bool recording;

  /// Kayıt sayacı metni ("0:12 / 1:00").
  final String timer;
  final bool flashOn;
  final VoidCallback onClose;
  final VoidCallback onFlash;
  final VoidCallback onGallery;
  final VoidCallback onFlip;
  final VoidCallback onPhoto;
  final VoidCallback onVideoStart;
  final VoidCallback onVideoEnd;
  final String closeLabel;
  final String flashLabel;
  final String galleryLabel;
  final String flipLabel;
  final String shutterLabel;
  final String hint;

  /// Kayıt halkasının dolum oranı (0-1): geçen süre / en uzun süre.
  final double progress;

  /// Galeri kısayolu küçük resmi (en yeni galeri öğesi); yoksa simge.
  final Uint8List? galleryThumb;

  /// Üst köşelerdeki 44 dp yarı saydam daire düğmesi (dokunma alanı 48 dp).
  Widget _glass(BuildContext context,
      {required Widget child, required String label, required VoidCallback onTap, Key? key, bool wide = false}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: BuPressable(
          key: key,
          onTap: onTap,
          haptic: BuHaptic.selection,
          child: wide
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: Center(widthFactor: 1, heightFactor: 1, child: child))
              : SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final pad = MediaQuery.paddingOf(context);
    final dim = t.scrim.withValues(alpha: .4);
    return Stack(children: [
      // Okunurluk için üst/alt karartma (referans: primary/70 -> saydam -> primary/80).
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.scrim.withValues(alpha: .6), t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .7)],
                stops: const [0, .45, 1],
              ),
            ),
          ),
        ),
      ),
      if (!recording)
        const Positioned.fill(child: IgnorePointer(child: Center(child: _FocusReticle()))),
      Positioned.fill(
        child: Column(children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, pad.top + 12, 16, 0),
            child: SizedBox(
              height: 48,
              child: Stack(alignment: Alignment.center, children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _glass(context,
                      label: closeLabel,
                      onTap: onClose,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: dim, shape: BoxShape.circle),
                        child: Icon(LucideIcons.x, size: 24, color: t.onMedia),
                      )),
                ),
                if (!recording)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _glass(context,
                        label: flashLabel,
                        onTap: onFlash,
                        wide: true,
                        child: AnimatedContainer(
                          duration: BuMotion.of(context, BuMotion.short),
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: flashOn ? t.pr : dim, borderRadius: BuRadius.bPill),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.zap, size: 20, color: flashOn ? t.onPr : t.onMedia),
                            BuGap.w6,
                            Text(flashLabel,
                                maxLines: 1,
                                style: tx.labelMedium!.copyWith(
                                    color: flashOn ? t.onPr : t.onMedia, fontWeight: FontWeight.w600, letterSpacing: .2)),
                          ]),
                        )),
                  ),
                if (recording)
                  Container(
                    key: const ValueKey('recPill'),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), borderRadius: BuRadius.bPill),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _PulseDot(color: t.pr),
                      BuGap.w8,
                      Text(timer,
                          maxLines: 1,
                          style: tx.labelLarge!.copyWith(
                              color: t.onMedia,
                              fontWeight: FontWeight.w600,
                              letterSpacing: .5,
                              fontFeatures: const [FontFeature.tabularFigures()])),
                    ]),
                  ),
              ]),
            ),
          ),
          const Spacer(),
          if (!recording)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: t.scrim.withValues(alpha: .6),
                  borderRadius: BuRadius.bPill,
                  border: Border.all(color: t.onMedia.withValues(alpha: .1)),
                ),
                child: Text(hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelMedium!.copyWith(color: t.onMedia.withValues(alpha: .9), fontWeight: FontWeight.w500)),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, pad.bottom + (recording ? 48 : 24)),
            child: recording ? _recordingBar(context) : _idleBar(context),
          ),
        ]),
      ),
    ]);
  }

  Widget _recordingBar(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        button: true,
        label: shutterLabel,
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('shutter'),
          behavior: HitTestBehavior.opaque,
          onTap: onVideoEnd,
          onLongPressEnd: (_) => onVideoEnd(),
          child: SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _RecRing(progress.clamp(0.0, 1.0), t.pr, t.onMedia.withValues(alpha: .2)),
              child: Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.onMedia.withValues(alpha: .1), shape: BoxShape.circle),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: t.pr, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      BuGap.h12,
      Text(shutterLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tx.labelLarge!.copyWith(
              color: t.onMedia,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
              shadows: [Shadow(color: t.scrim.withValues(alpha: .5), blurRadius: 4, offset: const Offset(0, 1))])),
    ]);
  }

  Widget _idleBar(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final cap = tx.labelMedium!.copyWith(color: t.onMedia.withValues(alpha: .8), fontWeight: FontWeight.w500);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 88,
        child: Column(children: [
          Semantics(
            button: true,
            label: galleryLabel,
            excludeSemantics: true,
            child: Tooltip(
              message: galleryLabel,
              child: BuPressable(
                key: const ValueKey('cameraGallery'),
                onTap: onGallery,
                haptic: BuHaptic.selection,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: t.nav,
                      borderRadius: BuRadius.bSm,
                      border: Border.all(color: t.onMedia.withValues(alpha: .2)),
                    ),
                    child: galleryThumb == null
                        ? Icon(LucideIcons.image, size: 22, color: t.onNav)
                        : Image.memory(galleryThumb!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 144),
                  ),
                ),
              ),
            ),
          ),
          BuGap.h6,
          Text(galleryLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: cap),
        ]),
      ),
      Expanded(
        child: Center(
          child: Semantics(
            button: true,
            label: shutterLabel,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('shutter'),
              onTap: onPhoto,
              onLongPressStart: (_) => onVideoStart(),
              onLongPressEnd: (_) => onVideoEnd(),
              child: SizedBox(
                width: 80,
                height: 80,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.onMedia, width: 3.5),
                    boxShadow: [BoxShadow(color: t.scrim.withValues(alpha: .25), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Center(
                    child: Container(width: 66, height: 66, decoration: BoxDecoration(color: t.onMedia, shape: BoxShape.circle)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 88,
        child: Column(children: [
          _glass(context,
              label: flipLabel,
              onTap: onFlip,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.scrim.withValues(alpha: .4),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.onMedia.withValues(alpha: .1)),
                ),
                child: Icon(LucideIcons.switchCamera, size: 24, color: t.onMedia),
              )),
          BuGap.h6,
          Text(flipLabel, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: cap),
        ]),
      ),
    ]);
  }
}

/// Odak çerçevesi: 192 dp, dört köşe ayracı + orta nokta (yalnız görsel).
class _FocusReticle extends StatelessWidget {
  const _FocusReticle();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: SizedBox(
        width: 192,
        height: 192,
        child: CustomPaint(painter: _ReticlePainter(t.onMedia.withValues(alpha: .8), t.onMedia.withValues(alpha: .7))),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  _ReticlePainter(this.line, this.dot);
  final Color line;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const a = 20.0;
    final w = size.width, h = size.height;
    canvas.drawPath(Path()..moveTo(0, a)..lineTo(0, 0)..lineTo(a, 0), p);
    canvas.drawPath(Path()..moveTo(w - a, 0)..lineTo(w, 0)..lineTo(w, a), p);
    canvas.drawPath(Path()..moveTo(0, h - a)..lineTo(0, h)..lineTo(a, h), p);
    canvas.drawPath(Path()..moveTo(w - a, h)..lineTo(w, h)..lineTo(w, h - a), p);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.line != line || old.dot != dot;
}

/// Kayıt halkası: 4 dp iz + yukarıdan saat yönünde dolan marka renkli yay.
class _RecRing extends CustomPainter {
  _RecRing(this.progress, this.color, this.track);
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(r.center, r.width / 2, base..color = track);
    if (progress > 0) {
      canvas.drawArc(r, -math.pi / 2, 2 * math.pi * progress, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RecRing old) => old.progress != progress || old.color != color || old.track != track;
}

/// Kayıt noktası: yavaş yanıp söner (hareket azaltılmışsa sabit).
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = BuMotion.reduced(context);
    if (_reduced == r) return;
    _reduced = r;
    if (r) {
      _c.stop();
      _c.value = 1;
    } else {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: .35, end: 1).animate(_c),
        child: Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      ),
    );
  }
}

/// "Video hazırlanıyor… %N" penceresi gövdesi (Stitch 25-6): ilerleme halkası + çizgisi, alt metin, İptal.
/// [progress] null ise belirsiz ilerleme. Çağıran diyalog/kapatma işini yapar.
class SohbetyVideoPrepareCard extends StatelessWidget {
  const SohbetyVideoPrepareCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cancelLabel,
    required this.onCancel,
    this.progress,
  });

  final String title;
  final String subtitle;
  final String cancelLabel;
  final VoidCallback onCancel;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final p = progress?.clamp(0.0, 1.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.sf3,
          borderRadius: BorderRadius.circular(24),
          boxShadow: BuElevation.of(context, 3),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: p,
                    strokeWidth: 4,
                    color: t.pr,
                    backgroundColor: t.sf2,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                ExcludeSemantics(child: Icon(LucideIcons.clapperboard, size: 26, color: t.ink)),
              ]),
            ),
          ),
          BuGap.h16,
          Semantics(
            liveRegion: true,
            child: Text(title, textAlign: TextAlign.center, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
          ),
          BuGap.h4,
          Text(subtitle, textAlign: TextAlign.center, style: tx.bodySmall!.copyWith(color: t.mut)),
          BuGap.h20,
          ClipRRect(
            borderRadius: BuRadius.bPill,
            child: LinearProgressIndicator(value: p, minHeight: 8, color: t.pr, backgroundColor: t.sf2),
          ),
          BuGap.h20,
          BuPressable(
            onTap: onCancel,
            haptic: BuHaptic.light,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
              child: Text(cancelLabel, style: tx.labelLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Önizleme/video hazırlama altındaki yığılı bildirim kartı (Stitch 25-6): uyarı/hata (kırmızı ton) ya da bilgi (koyu).
enum SohbetyNoticeKind { warning, error, info }

class SohbetyNoticeCard extends StatelessWidget {
  const SohbetyNoticeCard({super.key, required this.message, required this.kind, this.onClose});

  final String message;
  final SohbetyNoticeKind kind;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final info = kind == SohbetyNoticeKind.info;
    final bg = info ? t.nav : t.soft;
    final fg = info ? t.onNav : t.onSoft;
    final icon = switch (kind) {
      SohbetyNoticeKind.warning => LucideIcons.triangleAlert,
      SohbetyNoticeKind.error => LucideIcons.circleAlert,
      SohbetyNoticeKind.info => LucideIcons.info,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        decoration: BoxDecoration(color: bg, borderRadius: BuRadius.bMd),
        child: Row(children: [
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: info ? t.soft : t.danger, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: info ? t.onSoft : t.onMedia),
            ),
          ),
          BuGap.w12,
          Expanded(
            child: Text(message,
                style: tx.bodyMedium!.copyWith(color: fg, fontWeight: info ? FontWeight.w400 : FontWeight.w600, height: 1.3)),
          ),
          if (onClose != null)
            Semantics(
              button: true,
              label: context.l10n.p10CloseNotice,
              excludeSemantics: true,
              child: BuPressable(
                onTap: onClose,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(LucideIcons.x, size: 18, color: fg.withValues(alpha: .6)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
