import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';

/// Sohbet yardımcı ekranları (bilgi, yeni sohbet, rehber, ilet, kamera): ortak tasarım bileşenleri.

/// Tasarımdaki yumuşak kart gölgesi: 0 6 18 -12 rgba(23,30,51,.25).
const sohbetyShadow = [
  BoxShadow(
      color: Color(0x40171E33), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -12),
];

/// Büyük harf etiketler ("MEDYA · 24"); Türkçede i/ı doğru büyütülür.
String sohbetyUpper(BuildContext context, String s) {
  final lang = Localizations.maybeLocaleOf(context)?.languageCode;
  if (lang == 'tr') {
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return s.toUpperCase();
}

/// Üst başlık: 44 px geri düğmesi + 20 px / 800 başlık.
class SohbetyHeader extends StatelessWidget {
  const SohbetyHeader({super.key, required this.title, required this.onBack, this.trailing});

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
          16, MediaQuery.paddingOf(context).top + 12, 16, 12),
      child: Row(children: [
        BuIconButton(
            icon: LucideIcons.arrowLeft, onTap: onBack, tooltip: context.l10n.commonBack),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: t.ink)),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]),
    );
  }
}

/// Beyaz kart: 20 px köşe, ince çizgi, yumuşak gölge. Satırlar arasına çizgi koyar.
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.bd),
        boxShadow: sohbetyShadow,
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

/// Kart içi satır: en az [minHeight] yüksek, 16 px yan boşluk.
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

/// 36 px yumuşak kırmızı simge karosu (tehlike: kırmızı ton).
class SohbetyTile extends StatelessWidget {
  const SohbetyTile(
      {super.key, required this.icon, this.danger = false, this.size = 36, this.filled = false});

  final IconData icon;
  final bool danger;
  final double size;

  /// Dolu kırmızı zemin + beyaz simge (yeni grup).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: filled ? t.pr : t.soft,
            borderRadius: BorderRadius.circular(size > 36 ? 14 : 12)),
        child: Icon(icon,
            size: size > 36 ? 20 : 18,
            color: filled ? t.onPr : (danger ? t.danger : t.pr)),
      ),
    );
  }
}

/// Satırın iki satırlı metni: kalın ad + soluk alt satır.
class SohbetyTexts extends StatelessWidget {
  const SohbetyTexts(
      {super.key, required this.title, this.sub, this.color, this.weight = FontWeight.w700});

  final String title;
  final String? sub;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: weight,
                height: 1.3,
                color: color ?? t.ink)),
        if (sub != null && sub!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: t.mut)),
          ),
      ],
    );
  }
}

/// Bölüm etiketi: 12 px / 700, harf aralığı .06em, soluk.
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
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: .72,
              color: context.bu.mut)),
    );
  }
}

/// Arama / yazı alanı: 56 (ya da 48) px, 16 px köşe, beyaz, ince çizgi.
class SohbetyField extends StatelessWidget {
  const SohbetyField(
      {super.key,
      required this.hint,
      this.controller,
      this.onChanged,
      this.autofocus = false,
      this.height = 56});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      height: height,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bd),
      ),
      child: Row(children: [
        Icon(LucideIcons.search, size: height > 50 ? 20 : 18, color: t.mut),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            cursorColor: t.pr,
            style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: hint,
              hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 15, color: t.mut),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Fotoğrafsız avatar: yumuşak kırmızı zemin + baş harf(ler); fotoğraf varsa yuvarlak görsel.
class SohbetyAvatar extends StatelessWidget {
  const SohbetyAvatar(
      {super.key, required this.name, this.url, this.size = 48, this.headers, this.ring = false});

  final String name;
  final String? url;
  final double size;
  final Map<String, String>? headers;

  /// 3 px beyaz halka + gölge (sohbet bilgisi büyük avatarı).
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
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: size * .34,
                      fontWeight: FontWeight.w800,
                      color: t.onSoft)),
            ),
          );
    if (!(ring && has)) return inner;
    return Container(
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: t.sf, width: 3),
          boxShadow: sohbetyShadow),
      child: inner,
    );
  }
}

/// Tam genişlikli ana düğme: 56 px, 18 px köşe, kırmızı gölge.
class SohbetyButton extends StatelessWidget {
  const SohbetyButton(
      {super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: t.pr.withValues(alpha: .55),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                  spreadRadius: -12),
            ],
          ),
          child: Material(
            color: t.pr,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? onPressed : null,
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: Center(
                  child: busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: t.onPr))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: t.onPr)),
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

/// Seçim işareti: seçiliyken kırmızı dolu daire + onay, değilken 2 px çizgili boş daire.
class SohbetyCheck extends StatelessWidget {
  const SohbetyCheck({super.key, required this.on, this.size = 26});

  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? t.pr : Colors.transparent,
          border: on ? null : Border.all(color: t.bd, width: 2),
        ),
        child: on ? Icon(LucideIcons.check, size: 16, color: t.onPr) : null,
      ),
    );
  }
}

/// Sekme denetimi: beyaz zemin, 18 px köşe; seçili sekme kırmızı, 44 px yüksek.
class SohbetyTabs extends StatelessWidget {
  const SohbetyTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.sf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bd),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Row(children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == selected ? t.pr : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(labels[i],
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: i == selected ? t.onPr : t.mut)),
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

/// Kamera ekranı (koyu): kapat / sayaç / flaş, ipucu, galeri / deklanşör / çevir.
/// Önizleme arkada sayfa tarafından çizilir; bu katman yalnız denetimleri taşır.
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
  });

  final bool recording;
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

  static const _glass = Color(0x29FFFFFF); // rgba(255,255,255,.16)

  Widget _round(IconData icon, String label, VoidCallback onTap,
      {double size = 44, double icon_ = 20, bool on = false}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: on ? const Color(0xFFC62A20) : _glass, shape: BoxShape.circle),
            child: Icon(icon, size: icon_, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Column(children: [
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, pad.top + 12, 16, 0),
        child: Stack(alignment: Alignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _round(LucideIcons.x, closeLabel, onClose),
            _round(LucideIcons.zap, flashLabel, onFlash, on: flashOn),
          ]),
          if (recording)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFC62A20), borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(timer,
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
        ]),
      ),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xB30E1220), borderRadius: BorderRadius.circular(14)),
          child: Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      ),
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(32, 8, 32, pad.bottom + 32),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Semantics(
            button: true,
            label: galleryLabel,
            excludeSemantics: true,
            child: Tooltip(
              message: galleryLabel,
              child: GestureDetector(
                onTap: onGallery,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xB3FFFFFF), width: 1.5),
                  ),
                  child: const Icon(LucideIcons.image, size: 20, color: Colors.white),
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: shutterLabel,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('shutter'),
              onTap: onPhoto,
              onLongPressStart: (_) => onVideoStart(),
              onLongPressEnd: (_) => onVideoEnd(),
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                child: recording
                    ? Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: const Color(0xFFC62A20),
                            borderRadius: BorderRadius.circular(9)))
                    : Container(
                        width: 64,
                        height: 64,
                        decoration:
                            const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ),
          ),
          _round(LucideIcons.refreshCw, flipLabel, onFlip, size: 48, icon_: 22),
        ]),
      ),
    ]);
  }
}
