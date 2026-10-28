import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media.dart';
import 'media_pick.dart';
import 'message_bubble.dart' show OnceBadge;

const _kBg = Color(0xFF0E1322);

/// Gönderim öncesi tam ekran önizleme: sayfa sayfa gezinme, küçük resim şeridi (kaldırma),
/// açıklama alanı ve her fotoğrafta "tek gönderimlik" (1) düğmesi. Gönderince [MediaSendPlan] döner.
class MediaPreviewPage extends StatefulWidget {
  const MediaPreviewPage({super.key, required this.picks, this.onChanged});

  final List<MediaPick> picks;

  /// Öğe kaldırılınca kalan liste bildirilir (seçici senkron kalsın).
  final ValueChanged<List<MediaPick>>? onChanged;

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

  /// Gönder düğmesini örtmesin diye SnackBar yerine sayfa içi kısa bildirim.
  String? _note;
  Timer? _noteOff;

  void _toast(String msg) {
    setState(() => _note = msg);
    _noteOff?.cancel();
    _noteOff = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _note = null);
    });
  }

  void _toggleOnce(MediaPick p) {
    if (p.isVideo) return;
    setState(() {
      if (!_once.remove(p.key)) {
        _once.add(p.key);
        _toast(context.l10n.chatMiscOnceToast);
      }
    });
  }

  void _goto(int i) {
    setState(() => _index = i);
    _page.animateToPage(i, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _remove(int i) {
    final p = _picks[i];
    setState(() {
      _picks.removeAt(i);
      _once.remove(p.key);
      if (_index >= _picks.length) _index = _picks.length - 1;
    });
    widget.onChanged?.call(List.of(_picks));
    if (_picks.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_page.hasClients) _page.jumpToPage(_index);
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
    final t = context.bu;
    final l = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: _kBg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: Row(children: [
                Semantics(
                  button: true,
                  label: l.chatMiscClose,
                  child: GestureDetector(
                    key: const ValueKey('previewClose'),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle),
                      child: const Icon(LucideIcons.x, size: 20, color: Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: Text('${_picks.isEmpty ? 0 : _index + 1}/${_picks.length}',
                      key: const ValueKey('previewCounter'),
                      textAlign: TextAlign.center,
                      style: BuType.heading.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${_picks.length}/10',
                      key: const ValueKey('previewLimit'),
                      textAlign: TextAlign.end,
                      style: BuType.label.copyWith(color: const Color(0xFFC9CEDC))),
                ),
              ]),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                decoration: BoxDecoration(color: const Color(0xFF171E33), borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: PageView.builder(
                  key: const ValueKey('previewPages'),
                  controller: _page,
                  itemCount: _picks.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (c, i) => _pageFor(t, i),
                ),
              ),
            ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  key: const ValueKey('previewNote'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                  child: Text(_note!, textAlign: TextAlign.center, style: BuType.label.copyWith(color: Colors.white)),
                ),
              ),
            _strip(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsetsDirectional.only(start: 18, end: 18),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(24)),
                    alignment: Alignment.center,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const Icon(LucideIcons.textAlignStart, size: 18, color: Color(0xFFD5D9E6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('previewCaption'),
                          controller: _caption,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 1000,
                          buildCounter: (c, {required currentLength, required isFocused, maxLength}) => null,
                          textCapitalization: TextCapitalization.sentences,
                          style: BuType.body.copyWith(color: Colors.white, fontSize: 15),
                          cursorColor: Colors.white,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            hintText: l.chatMiscAddCaption,
                            hintStyle: BuType.body.copyWith(color: const Color(0xFFD5D9E6), fontSize: 15),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: l.sohbetmedyaSendItems(_picks.length.toString()),
                  child: GestureDetector(
                    key: const ValueKey('previewSend'),
                    onTap: _send,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          decoration: BoxDecoration(
                            color: t.pr,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: t.pr.withValues(alpha: .4), blurRadius: 20, offset: const Offset(0, 10), spreadRadius: -10)],
                          ),
                          alignment: Alignment.center,
                          child: Icon(Directionality.of(context) == TextDirection.rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
                              size: 22, color: t.onPr),
                        ),
                        PositionedDirectional(
                          top: -4,
                          end: -4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _kBg, width: 2),
                            ),
                            child: Text('${_picks.length}',
                                style: BuType.label.copyWith(color: t.pr, fontWeight: FontWeight.w800, height: 1.1)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pageFor(BuTokens t, int i) {
    final p = _picks[i];
    final on = _once.contains(p.key);
    return Stack(fit: StackFit.expand, children: [
      FutureBuilder<Uint8List?>(
        future: _fullOf(p),
        builder: (c, s) => s.data == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white54))
            : Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
                Image.memory(s.data!, fit: BoxFit.contain, gaplessPlayback: true),
                if (p.isVideo)
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.play, color: Colors.white, size: 23.5),
                    ),
                  ),
              ]),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 96,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_kBg.withValues(alpha: .85), _kBg.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
      if (p.isVideo)
        PositionedDirectional(
          start: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _kBg.withValues(alpha: .78), borderRadius: BorderRadius.circular(999)),
            child: Text(formatMediaDuration(p.durationMs), style: BuType.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        )
      else
        PositionedDirectional(
          start: 12,
          bottom: 12,
          child: Semantics(
            button: true,
            toggled: on,
            label: context.l10n.chatMiscOnceSendLabel,
            excludeSemantics: true,
            child: GestureDetector(
              key: ValueKey('onceButton_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleOnce(p),
              child: Container(
                height: 44,
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: on ? t.pr : _kBg.withValues(alpha: .78),
                ),
                alignment: Alignment.center,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const OnceBadge(color: Colors.white, size: 20, dashed: false),
                  const SizedBox(width: 8),
                  Text(context.l10n.chatMiscOnceSendLabel,
                      style: BuType.label.copyWith(color: on ? t.onPr : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _strip(BuTokens t) {
    final canAdd = _picks.length < 10;
    return SizedBox(
      height: 80,
      child: ListView.separated(
        key: const ValueKey('previewStrip'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        itemCount: _picks.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          if (i == _picks.length) {
            return Semantics(
              button: true,
              label: context.l10n.sohbetmedyaAddMore,
              child: GestureDetector(
                key: const ValueKey('previewAdd'),
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: _DashedRRect(Colors.white.withValues(alpha: .55)),
                    child: const Center(child: Icon(LucideIcons.plus, size: 22, color: Colors.white)),
                  ),
                ),
              ),
            );
          }
          final p = _picks[i];
          final active = i == _index;
          return SizedBox(
            width: 56,
            height: 56,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: GestureDetector(
                  key: ValueKey('previewThumb_$i'),
                  onTap: () => _goto(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? Colors.white : Colors.transparent, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(fit: StackFit.expand, children: [
                      FutureBuilder<Uint8List?>(
                        future: p.thumb(200),
                        builder: (c, s) => s.data == null
                            ? const ColoredBox(color: Colors.white12)
                            : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 200),
                      ),
                      if (p.isVideo)
                        PositionedDirectional(
                          start: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .65), borderRadius: BorderRadius.circular(8)),
                            child: Text(formatMediaDuration(p.durationMs),
                                style: BuType.micro.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
                PositionedDirectional(
                  top: -6,
                  end: -6,
                  child: GestureDetector(
                    key: ValueKey('previewRemove_$i'),
                    onTap: () => _remove(i),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(LucideIcons.x, size: 10, color: Color(0xFF171E33)),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Tasarımdaki kesikli çerçeveli "ekle" karosu.
class _DashedRRect extends CustomPainter {
  _DashedRRect(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRect old) => old.color != color;
}
