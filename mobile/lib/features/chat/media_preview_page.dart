import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_media.dart';
import 'media_pick.dart';

/// Gönderim öncesi tam ekran önizleme (Stitch 25-4): sayfa sayfa gezinme, "1 / 3" sayacı, açıklama alanı,
/// "Tek gönderimlik" hapı, küçük resim şeridi ve "N öğeyi gönder". Gönderince [MediaSendPlan] döner;
/// kapatılırsa null (seçici seçimi korur). Medya sahnesi her temada koyudur.
class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({super.key, required this.picks});

  final List<MediaPick> picks;

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  late final List<MediaPick> _picks = List.of(widget.picks);
  final _once = <String>{};
  final _page = PageController();
  final _caption = TextEditingController();
  final _full = <String, Future<Uint8List?>>{};
  int _index = 0;

  /// Marka rengi: medya sahnesi koyu olsa da uygulamanın (açık/koyu) kırmızısı kullanılır.
  Color _pr = const Color(0x00000000);
  Color _onPr = const Color(0x00000000);

  /// "Tek gönderimlik: alıcı yalnızca bir kez görebilir" bildirimi (kapatılabilir, kısa süre sonra kendiliğinden gider).
  bool _note = false;
  Timer? _noteOff;

  @override
  void dispose() {
    _noteOff?.cancel();
    _page.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<Uint8List?> _fullOf(MediaPick p) => _full.putIfAbsent(p.key, () async {
        if (!p.isVideo && p.imageBytes != null) {
          final b = await p.imageBytes!();
          if (b != null) return b;
        }
        return p.thumb(1080);
      });

  void _showNote() {
    setState(() => _note = true);
    _noteOff?.cancel();
    _noteOff = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _note = false);
    });
  }

  void _hideNote() {
    _noteOff?.cancel();
    setState(() => _note = false);
  }

  void _toggleOnce(MediaPick p) {
    if (p.isVideo) return;
    buHaptic(BuHaptic.light);
    if (_once.contains(p.key)) {
      setState(() => _once.remove(p.key));
      _hideNote();
    } else {
      setState(() => _once.add(p.key));
      _showNote();
    }
  }

  void _goto(int i) {
    buHaptic();
    setState(() => _index = i);
    _page.animateToPage(i, duration: BuMotion.of(context, BuMotion.short), curve: BuMotion.standard);
  }

  void _send() {
    if (_picks.isEmpty) return;
    Navigator.pop(
      context,
      MediaSendPlan([for (final p in _picks) MediaSendItem(p, once: _once.contains(p.key))], _caption.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outer = context.bu;
    _pr = outer.pr;
    _onPr = outer.onPr;
    // Koyu belirteçler: medya sahnesi her temada koyu.
    final dark = BuTheme.forLocale(Brightness.dark, Localizations.localeOf(context).languageCode);
    return Theme(
      data: dark,
      child: Builder(builder: (context) {
        final t = context.bu;
        return Scaffold(
          backgroundColor: t.bg,
          resizeToAvoidBottomInset: true,
          body: Stack(children: [
            // Üstte hafif marka parıltısı (referans: bulanık kırmızı halka).
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -1.05),
                      radius: .8,
                      colors: [_pr.withValues(alpha: .16), _pr.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(children: [
                _topBar(context),
                Expanded(child: _canvas(context)),
                _controls(context),
                _strip(context),
                _sendButton(context),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  Widget _topBar(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      child: SizedBox(
        height: 48,
        child: Stack(alignment: Alignment.center, children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              button: true,
              label: l.chatMiscClose,
              excludeSemantics: true,
              child: BuPressable(
                key: const ValueKey('previewClose'),
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .6), shape: BoxShape.circle),
                      child: Icon(LucideIcons.x, size: 20, color: t.onMedia),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: t.scrim.withValues(alpha: .7), borderRadius: BuRadius.bPill),
            child: Text('${_picks.isEmpty ? 0 : _index + 1} / ${_picks.length}',
                key: const ValueKey('previewCounter'),
                textDirection: TextDirection.ltr,
                style: tx.labelMedium!.copyWith(color: t.onMedia, fontWeight: FontWeight.w600, letterSpacing: .6)),
          ),
        ]),
      ),
    );
  }

  /// 4:5 oranlı, 24 dp köşeli ana tuval; sığmazsa (klavye, küçük ekran) oranı koruyarak küçülür.
  Widget _canvas(BuildContext context) {
    final t = context.bu;
    return LayoutBuilder(builder: (context, c) {
      final maxW = c.maxWidth - 32;
      final w = maxW < c.maxHeight * .8 ? maxW : c.maxHeight * .8;
      return Center(
        child: SizedBox(
          width: w < 0 ? 0 : w,
          height: w < 0 ? 0 : w / .8,
          child: Container(
            decoration: BoxDecoration(
              color: t.scrim,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              PageView.builder(
                key: const ValueKey('previewPages'),
                controller: _page,
                itemCount: _picks.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (c, i) => _pageFor(c, i),
              ),
              // Alttan koyulaşan örtü (referans: primary/90 -> saydam -> primary/30).
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [t.scrim.withValues(alpha: .6), t.scrim.withValues(alpha: 0), t.scrim.withValues(alpha: .2)],
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }

  Widget _pageFor(BuildContext context, int i) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final p = _picks[i];
    return Stack(fit: StackFit.expand, children: [
      FutureBuilder<Uint8List?>(
        future: _fullOf(p),
        builder: (c, s) => AnimatedSwitcher(
          duration: BuMotion.of(context, BuMotion.medium),
          child: s.data == null
              ? Center(
                  key: const ValueKey('loading'),
                  child: Icon(p.isVideo ? LucideIcons.video : LucideIcons.image, size: 36, color: t.onMedia.withValues(alpha: .4)),
                )
              : Stack(key: const ValueKey('ready'), alignment: Alignment.center, fit: StackFit.expand, children: [
                  Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 1080),
                  if (p.isVideo)
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(color: t.scrim.withValues(alpha: .55), shape: BoxShape.circle),
                        child: Icon(LucideIcons.play, color: t.onMedia, size: 26),
                      ),
                    ),
                ]),
        ),
      ),
      if (p.isVideo)
        PositionedDirectional(
          start: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: t.scrim.withValues(alpha: .7), borderRadius: BuRadius.bPill),
            child: Text(formatMediaDuration(p.durationMs), style: tx.labelLarge!.copyWith(color: t.onMedia)),
          ),
        ),
    ]);
  }

  /// Bildirim hapı + açıklama alanı + "Tek gönderimlik" hapı.
  Widget _controls(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final cur = _picks.isEmpty ? null : _picks[_index.clamp(0, _picks.length - 1)];
    final canOnce = cur != null && !cur.isVideo;
    final on = cur != null && _once.contains(cur.key);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.short),
          alignment: Alignment.topCenter,
          child: _note && on
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: Container(
                      key: const ValueKey('previewNote'),
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 2, 0),
                      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .95), borderRadius: BuRadius.bPill),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ExcludeSemantics(child: Icon(LucideIcons.info, size: 16, color: _pr)),
                        BuGap.w8,
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(l.chatMiscOnceToast,
                                style: tx.bodySmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l.p10CloseNotice,
                          excludeSemantics: true,
                          child: BuPressable(
                            key: const ValueKey('previewNoteClose'),
                            onTap: _hideNote,
                            child: SizedBox(
                                width: 48, height: 40, child: Icon(LucideIcons.x, size: 16, color: t.onMedia.withValues(alpha: .7))),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Row(children: [
          Expanded(child: _captionField(context)),
          if (canOnce) ...[
            BuGap.w8,
            Semantics(
              button: true,
              toggled: on,
              label: l.chatMiscOnceSendLabel,
              excludeSemantics: true,
              child: BuPressable(
                key: ValueKey('onceButton_$_index'),
                onTap: () => _toggleOnce(cur),
                child: AnimatedContainer(
                  duration: BuMotion.of(context, BuMotion.short),
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: on ? _pr : t.scrim.withValues(alpha: .6),
                    borderRadius: BuRadius.bPill,
                    border: on ? null : Border.all(color: t.onMedia.withValues(alpha: .25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: on ? _onPr : t.onMedia, shape: BoxShape.circle),
                      child: Text('1',
                          style: tx.labelSmall!.copyWith(
                              color: on ? _pr : t.scrim, fontWeight: FontWeight.w800, height: 1)),
                    ),
                    BuGap.w6,
                    Text(l.chatMiscOnceSendLabel,
                        maxLines: 1,
                        style: tx.labelMedium!.copyWith(color: on ? _onPr : t.onMedia, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _captionField(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: t.onMedia.withValues(alpha: .95), borderRadius: BorderRadius.circular(24)),
      alignment: Alignment.center,
      child: Row(children: [
        ExcludeSemantics(child: Icon(LucideIcons.messageSquareText, size: 18, color: t.scrim.withValues(alpha: .6))),
        BuGap.w8,
        Expanded(
          child: TextField(
            key: const ValueKey('previewCaption'),
            controller: _caption,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            buildCounter: (c, {required currentLength, required isFocused, maxLength}) => null,
            textCapitalization: TextCapitalization.sentences,
            style: tx.bodyMedium!.copyWith(color: t.scrim),
            cursorColor: _pr,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              hintText: l.chatMiscAddCaption,
              hintStyle: tx.bodyMedium!.copyWith(color: t.scrim.withValues(alpha: .55)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _strip(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        key: const ValueKey('previewStrip'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        itemCount: _picks.length,
        separatorBuilder: (_, __) => BuGap.w8,
        itemBuilder: (c, i) => _StripThumb(
          key: ValueKey('stripItem_${_picks[i].key}'),
          index: i,
          pick: _picks[i],
          active: i == _index,
          accent: _pr,
          onTap: () => _goto(i),
        ),
      ),
    );
  }

  Widget _sendButton(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final label = context.l10n.sohbetmedyaSendItems(_picks.length.toString());
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: BuPressable(
          key: const ValueKey('previewSend'),
          onTap: _send,
          haptic: BuHaptic.light,
          child: Container(
            height: BuSize.button,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pr,
              borderRadius: BuRadius.bMd,
              boxShadow: [BoxShadow(color: t.scrim.withValues(alpha: .35), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -6)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelLarge!.copyWith(color: _onPr, fontWeight: FontWeight.w600, letterSpacing: .3)),
              ),
              BuGap.w8,
              Transform.flip(flipX: rtl, child: Icon(LucideIcons.send, size: 20, color: _onPr)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Şerit küçük resmi: 56 dp, 12 dp köşe; etkin olan kırmızı çerçeveli ve biraz büyük, diğerleri soluk.
class _StripThumb extends StatefulWidget {
  const _StripThumb(
      {super.key, required this.index, required this.pick, required this.active, required this.onTap, required this.accent});

  final int index;
  final MediaPick pick;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  State<_StripThumb> createState() => _StripThumbState();
}

class _StripThumbState extends State<_StripThumb> {
  late final Future<Uint8List?> _thumb = widget.pick.thumb(200);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final p = widget.pick;
    final a = widget.active;
    return Center(
      child: GestureDetector(
        key: ValueKey('previewThumb_${widget.index}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: a ? 1.05 : 1,
          duration: BuMotion.of(context, BuMotion.short),
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: a ? widget.accent : widget.accent.withValues(alpha: 0), width: 3),
            ),
            child: ClipRRect(
              borderRadius: BuRadius.bSm,
              child: Stack(fit: StackFit.expand, children: [
                FutureBuilder<Uint8List?>(
                  future: _thumb,
                  builder: (c, s) => s.data == null
                      ? ColoredBox(color: t.onMedia.withValues(alpha: .12))
                      : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 200),
                ),
                if (!a) ColoredBox(color: t.scrim.withValues(alpha: .3)),
                if (p.isVideo)
                  PositionedDirectional(
                    start: 3,
                    bottom: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: t.scrim.withValues(alpha: .7), borderRadius: BuRadius.bPill),
                      child: Text(formatMediaDuration(p.durationMs),
                          style: tx.labelSmall!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700)),
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
