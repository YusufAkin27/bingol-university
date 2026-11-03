import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/locale_controller.dart';
import '../../../widgets/bu.dart';
import 'auth_ref.dart';

/// Giriş için "alt sayfa" iskeleti (Wallet / Müzik hissi): üstte sakin nötr zeminde marka + karşılama başlığı
/// (ekranın yaklaşık üçte biri), altında üst köşeleri 28 dp yuvarlak, ince çizgili beyaz yüzey (sheet) içinde form.
/// Klavye açılınca üst bölüm sıkışır ve sheet yumuşakça yükselir. Yalnız `context.bu` ve [AppMotion].
class LoginSheetPage extends StatelessWidget {
  const LoginSheetPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.showBack = false,
  });

  final String title;
  final String subtitle;

  /// Sheet içeriği (bantlar + form); kaydırılır.
  final List<Widget> children;

  /// Sheet'in dibine yapışan alt bölüm (ince çizgiyle ayrılır); null ise yok.
  final Widget? footer;
  final bool showBack;

  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final mq = MediaQuery.of(context);
    // Scaffold gövdesi klavye boşluğunu kaldırdığı için klavye durumu Scaffold'un DIŞINDA okunur.
    final keyboard = mq.viewInsets.bottom > 0;
    final avail = mq.size.height - mq.padding.top;
    final scale = mq.textScaler.scale(16) / 16;
    final fullH = math.min(360.0, math.max(avail * .34, 160.0 * math.max(1.0, scale)));
    final compactH = showBack ? 64.0 : 56.0 + 4 * (scale - 1).clamp(0.0, 1.0);
    final dur = AppMotion.of(context, AppMotion.sheet);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AnimatedContainer(
              duration: dur,
              curve: AppMotion.enter,
              height: keyboard ? compactH : fullH,
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.normal),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: keyboard
                    ? _CompactHeader(key: const ValueKey('login-header-compact'), showBack: showBack)
                    : _FullHeader(key: const ValueKey('login-header-full'), title: title, subtitle: subtitle, showBack: showBack),
              ),
            ),
            Expanded(child: _Sheet(footer: footer, children: children)),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: context.l10n.authBack,
      excludeSemantics: true,
      onTap: () => Navigator.maybePop(context),
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(buDirIcon(context, BuIcons.arrowLeft), color: t.ink, size: 24),
        onPressed: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// Marka karosu + "BÜ Kampüs" yazısı (özel ad: dile göre değişmez).
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.size, required this.style});

  final double size;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RefBrandMark(size: size),
        const SizedBox(width: 12),
        Flexible(child: Text('BÜ Kampüs', style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _FullHeader extends StatelessWidget {
  const _FullHeader({super.key, required this.title, required this.subtitle, required this.showBack});

  final String title;
  final String subtitle;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Stack(
      children: [
        // Çok sakin, yalnız ince çizgiden oluşan halkalar (renkli alan yok).
        Positioned.fill(
          child: ExcludeSemantics(
            child: CustomPaint(painter: _RingsPainter(color: t.bd, rtl: Directionality.of(context) == TextDirection.rtl)),
          ),
        ),
        if (showBack) const PositionedDirectional(top: 8, start: 8, child: _BackButton()),
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              reverse: true,
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BrandRow(size: 44, style: tx.titleMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),
                        Semantics(
                          header: true,
                          child: Text(title, style: tx.headlineMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w700, height: 1.15)),
                        ),
                        const SizedBox(height: 6),
                        Text(subtitle, style: tx.bodyLarge!.copyWith(color: t.mut, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Klavye açıkken: tek satır (geri + küçük marka).
class _CompactHeader extends StatelessWidget {
  const _CompactHeader({super.key, required this.showBack});

  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: showBack ? 8 : 24, end: 24),
      child: Row(
        children: [
          if (showBack) const _BackButton(),
          if (showBack) const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _BrandRow(size: 32, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.color, required this.rtl});

  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // Sağ üst (RTL'de sol üst) köşeye açılan ince eş merkezli halkalar; sayfaya doğru solar.
    final cx = rtl ? size.width * .12 : size.width * .88;
    final c = Offset(cx, size.height * .22);
    const radii = [44.0, 84.0, 124.0, 164.0];
    for (var i = 0; i < radii.length; i++) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: (1 - i * .22).clamp(.2, 1.0));
      canvas.drawCircle(c, radii[i], p);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.color != color || old.rtl != rtl;
}

/// Sheet yüzeyi: beyaz, üst köşeler 28 dp, ince çizgi; gövde kayar, alt bölüm dibe yapışır.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.children, required this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dur = AppMotion.of(context, AppMotion.sheet);
    // Alt kenarlık ekran dışında kalsın diye yüzey alta doğru taşırılır (yalnız üst çizgi/köşe görünür).
    const bleed = 40.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: dur,
      curve: AppMotion.enter,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 36), child: child),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -1,
            right: -1,
            top: 0,
            bottom: -bleed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.sf,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(LoginSheetPage.radius)),
                border: Border.all(color: t.bd),
              ),
            ),
          ),
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final bottom = MediaQuery.paddingOf(context).bottom;
                return LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: BuStaggerScope(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(24, 28, 24, 12 + bottom),
                              // Alt bölüm boşluk varsa dibe iner (spaceBetween), yoksa içeriğin altında kayar.
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minHeight: math.max(0.0, c.maxHeight - 40 - bottom)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                                    if (footer != null) footer!,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
