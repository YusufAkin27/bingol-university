import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'chat_media.dart';
import 'media_pick.dart';
import 'message_bubble.dart' show OnceBadge;

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
        _toast('Tek gönderimlik: alıcı yalnızca bir kez görebilir');
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
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0C),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  key: const ValueKey('previewClose'),
                  tooltip: 'Kapat',
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text('${_picks.isEmpty ? 0 : _index + 1}/${_picks.length}',
                    key: const ValueKey('previewCounter'),
                    style: BuType.bodyStrong.copyWith(color: Colors.white)),
                const SizedBox(width: 10),
                Text('${_picks.length}/10',
                    key: const ValueKey('previewLimit'),
                    style: BuType.label.copyWith(color: Colors.white70)),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('previewPages'),
                controller: _page,
                itemCount: _picks.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (c, i) => _pageFor(t, i),
              ),
            ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  key: const ValueKey('previewNote'),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                  child: Text(_note!, textAlign: TextAlign.center, style: BuType.label.copyWith(color: Colors.white)),
                ),
              ),
            _strip(t),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(23)),
                    alignment: Alignment.center,
                    child: TextField(
                      key: const ValueKey('previewCaption'),
                      controller: _caption,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      buildCounter: (c, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      style: BuType.body.copyWith(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        hintText: 'Açıklama ekle…',
                        hintStyle: BuType.body.copyWith(color: Colors.white54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Gönder',
                  child: GestureDetector(
                    key: const ValueKey('previewSend'),
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
                      child: Icon(LucideIcons.send, size: 20, color: t.onPr),
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
    return Stack(children: [
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FutureBuilder<Uint8List?>(
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
        ),
      ),
      if (p.isVideo)
        PositionedDirectional(
          start: 16,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
            child: Text(formatMediaDuration(p.durationMs), style: BuType.label.copyWith(color: Colors.white)),
          ),
        )
      else
        PositionedDirectional(
          end: 16,
          bottom: 12,
          child: Semantics(
            button: true,
            toggled: on,
            label: 'Tek gönderimlik',
            child: GestureDetector(
              key: ValueKey('onceButton_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleOnce(p),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? t.pr : Colors.black.withValues(alpha: .55),
                ),
                alignment: Alignment.center,
                child: const OnceBadge(color: Colors.white, size: 26, dashed: false),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _strip(BuTokens t) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        key: const ValueKey('previewStrip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _picks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? t.pr : Colors.transparent, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<Uint8List?>(
                      future: p.thumb(200),
                      builder: (c, s) => s.data == null
                          ? const ColoredBox(color: Colors.white12)
                          : Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 200),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 0,
                end: 0,
                child: GestureDetector(
                  key: ValueKey('previewRemove_$i'),
                  onTap: () => _remove(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.x, size: 11.5, color: Colors.white),
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
