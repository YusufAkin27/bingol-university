import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Sohbet baloncuğu. Durumsuzdur; tüm veri ve geri çağrılar sayfadan gelir.
///
/// Yerel alanlar: `_state` (pending|failed), `_error`, `_bytes` (yüklenen görselin yerel önizlemesi).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.senderName,
    required this.replyName,
    required this.seen,
    required this.authHeaders,
    required this.onMenu,
    required this.onRetry,
    required this.onOpenImage,
    required this.onReact,
    this.tail = true,
    this.replyMine = false,
    this.onReplyTap,
    this.onMenuRect,
    this.preview = false,
    this.onSwipeReply,
  });

  final Map<String, dynamic> message;
  final bool mine;

  /// Grup sohbetinde gelen mesajın üstünde görünen ad (yoksa null).
  final String? senderName;
  final String? replyName;

  /// Giden mesaj karşı tarafça okundu mu.
  final bool seen;
  final Map<String, String> authHeaders;
  final VoidCallback onMenu;
  final VoidCallback onRetry;
  final void Function(Map<String, dynamic> attachment) onOpenImage;
  final void Function(String emoji) onReact;

  /// Kuyruk köşesi (ardışık aynı gönderenin mesajlarında yalnız sonuncuda true).
  final bool tail;

  /// Alıntılanan mesaj benim mi (alıntı çizgisinin rengi).
  final bool replyMine;

  /// Alıntıya dokunma (ilgili mesaja kaydır).
  final VoidCallback? onReplyTap;

  /// Verilirse menü, baloncuğun ekran dikdörtgeniyle açılır (yoksa [onMenu]).
  final void Function(Rect bubbleRect)? onMenuRect;

  /// Menü önizlemesi: yalnız baloncuk gövdesi, etkileşimsiz.
  final bool preview;

  /// Verilirse baloncuk yatay sürüklenerek yanıtlanabilir (null: kapalı).
  final VoidCallback? onSwipeReply;

  void _openMenu(BuildContext bc) {
    final cb = onMenuRect;
    final ro = bc.findRenderObject();
    if (cb != null && ro is RenderBox && ro.hasSize) {
      cb(ro.localToGlobal(Offset.zero) & ro.size);
    } else {
      onMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = message;
    final deleted = m['deleted'] == true;
    final removed = m['removed'] == true;
    final state = m['_state'] as String?;
    final fg = mine ? t.onPr : t.ink;
    final metaColor = mine ? t.onPr.withValues(alpha: .75) : t.mut;
    final d = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
    final reply = m['replyTo'] is Map ? Map<String, dynamic>.from(m['replyTo'] as Map) : null;
    final text = deleted ? 'Bu mesaj silindi' : (m['text'] as String?) ?? '';
    final maxW = MediaQuery.sizeOf(context).width * .78;
    final atts = (deleted || removed) ? const <Map<String, dynamic>>[] : _attachments(m);
    final localBytes = m['_bytes'] as Uint8List?;
    final hasMedia = atts.isNotEmpty || localBytes != null;
    final reactions = (m['reactions'] as List? ?? const []).whereType<Map>().toList();
    final myReaction = m['myReaction'] as String?;
    final showText = text.isNotEmpty && !(hasMedia && (m['text'] as String? ?? '').isEmpty);

    final metaText = [
      if (m['edited'] == true && !deleted) 'düzenlendi',
      if (d != null) '${_two(d.hour)}:${_two(d.minute)}',
    ].join(' · ');
    final statusIcon = !mine
        ? null
        : state == 'pending'
            ? LucideIcons.clock
            : state == 'failed'
                ? null
                : seen
                    ? LucideIcons.checkCheck
                    : (m['id'] != null ? LucideIcons.check : null);
    final hasMeta = metaText.isNotEmpty || statusIcon != null;

    Widget metaRow(Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (metaText.isNotEmpty) Text(metaText, style: BuType.micro.copyWith(color: color)),
          if (statusIcon != null) ...[
            const SizedBox(width: 3),
            Semantics(label: seen ? 'Okundu' : 'Gönderildi', child: Icon(statusIcon, size: 14, color: color)),
          ],
        ]);

    final textStyle = BuType.body.copyWith(
      color: (deleted || removed) ? fg.withValues(alpha: .7) : fg,
      fontStyle: (deleted || removed) ? FontStyle.italic : FontStyle.normal,
    );

    // Saat, metnin son satırına sığıyorsa aynı satırda, sığmıyorsa alt satırın sağında durur (boşluk ayrılır).
    Widget textWithMeta() {
      if (!hasMeta) return Text(text, style: textStyle);
      final scaler = MediaQuery.textScalerOf(context);
      final mp = TextPainter(
        text: TextSpan(text: metaText, style: BuType.micro),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final metaW = mp.width + (statusIcon != null ? 17 : 0) + 8;
      final metaH = math.max(mp.height, 14.0);
      mp.dispose();
      return LayoutBuilder(builder: (c, cons) {
        final maxWidth = cons.maxWidth.isFinite ? cons.maxWidth : 400.0;
        final tp = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout(maxWidth: maxWidth);
        final lines = tp.computeLineMetrics();
        final lastW = lines.isEmpty ? 0.0 : lines.last.width;
        final longest = lines.fold<double>(0, (a, l) => math.max(a, l.width));
        final textH = tp.height;
        tp.dispose();
        final inline = lastW + metaW <= maxWidth;
        final width = math.min(maxWidth, math.max(longest, inline ? lastW + metaW : metaW));
        return SizedBox(
          width: width,
          height: inline ? textH : textH + metaH,
          child: Stack(children: [
            Positioned(left: 0, top: 0, right: 0, child: Text(text, style: textStyle)),
            Positioned(right: 0, bottom: 0, child: metaRow(metaColor)),
          ]),
        );
      });
    }

    // Yalnız görsel: saat görselin sağ altında yarı saydam koyu hap.
    Widget mediaWithPill(Widget media) {
      if (showText || !hasMeta) return media;
      return Stack(children: [
        media,
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(999)),
            child: metaRow(Colors.white),
          ),
        ),
      ]);
    }

    final w = (maxW - 12).clamp(140.0, 300.0);
    Widget? mediaBlock;
    if (localBytes != null) {
      mediaBlock = _LocalImage(bytes: localBytes, uploading: state == 'pending', maxW: maxW);
    } else if (atts.length == 1) {
      mediaBlock = _AttachmentImage(attachment: atts.first, headers: authHeaders, maxW: maxW - 12, onTap: () => onOpenImage(atts.first));
    } else if (atts.length > 1) {
      final cell = (w - 4) / 2;
      final shown = atts.take(4).toList();
      mediaBlock = SizedBox(
        width: w,
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < shown.length; i++)
            _AttachmentImage(
              attachment: shown[i],
              headers: authHeaders,
              maxW: maxW - 12,
              side: cell,
              more: (i == 3 && atts.length > 4) ? atts.length - 4 : 0,
              onTap: () => onOpenImage(shown[i]),
            ),
        ]),
      );
    }

    const r = Radius.circular(18);
    const small = Radius.circular(5);
    final body = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: EdgeInsets.symmetric(horizontal: hasMedia ? 6 : 14, vertical: hasMedia ? 6 : 9),
      decoration: BoxDecoration(
        color: mine ? t.pr : t.sf,
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: (mine || !tail) ? r : small,
          bottomRight: (mine && tail) ? small : r,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (senderName != null)
          Padding(
            padding: EdgeInsets.fromLTRB(hasMedia ? 8 : 0, hasMedia ? 4 : 0, 0, 3),
            child: Text(senderName!, style: BuType.label.copyWith(color: t.pr)),
          ),
        if (reply != null && !deleted) _quote(t, reply, fg),
        if (mediaBlock != null)
          Padding(
            padding: EdgeInsets.only(bottom: showText ? 4 : 0),
            child: mediaWithPill(mediaBlock),
          ),
        if (showText)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hasMedia ? 8 : 0, vertical: hasMedia ? 2 : 0),
            child: textWithMeta(),
          ),
      ]),
    );

    if (preview) return body;

    final gestureBubble = Builder(
      builder: (bc) => GestureDetector(
        onLongPress: state == 'pending' ? null : () => _openMenu(bc),
        onTap: state == null || state == 'failed' ? () => _openMenu(bc) : null,
        child: body,
      ),
    );

    final column = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          gestureBubble,
          // Tepkiler baloncuğun alt kenarına hafifçe biner.
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Transform.translate(
                offset: const Offset(0, -9),
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final rx in reactions)
                    _ReactionChip(
                      emoji: '${rx['emoji']}',
                      count: (rx['count'] as num?)?.toInt() ?? 0,
                      mine: myReaction == rx['emoji'],
                      onTap: () => onReact('${rx['emoji']}'),
                    ),
                ]),
              ),
            ),
          if (state == 'failed')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: onRetry,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.circleAlert, size: 14, color: t.danger),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('${(m['_error'] as String?) ?? 'Gönderilemedi'} · Yeniden dene',
                        style: BuType.micro.copyWith(color: t.danger, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
    return onSwipeReply == null ? column : _SwipeReply(onReply: onSwipeReply!, child: column);
  }

  /// Yanıt alıntısı: solda renkli ince çizgi (kendi mesajım / başkasınınki).
  Widget _quote(BuTokens t, Map<String, dynamic> reply, Color fg) {
    final bar = mine
        ? t.onPr.withValues(alpha: replyMine ? .95 : .5)
        : (replyMine ? t.pr : t.ok);
    final raw = reply['deleted'] == true ? 'Bu mesaj silindi' : (reply['text'] as String?) ?? '';
    final quoted = raw.isEmpty ? 'Fotoğraf' : raw;
    final box = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: mine ? Colors.white.withValues(alpha: .18) : Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(width: 3, color: bar),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(replyName ?? 'Kullanıcı', maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.micro.copyWith(color: fg, fontWeight: FontWeight.w700)),
                Text(quoted, maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: fg.withValues(alpha: .9))),
              ]),
            ),
          ),
        ]),
      ),
    );
    return onReplyTap == null ? box : GestureDetector(onTap: onReplyTap, child: box);
  }

  static List<Map<String, dynamic>> _attachments(Map<String, dynamic> m) =>
      (m['attachments'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.emoji, required this.count, required this.mine, required this.onTap});

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: mine ? Color.alphaBlend(t.pr.withValues(alpha: .14), t.sf) : t.sf,
          border: Border.all(color: mine ? t.pr : t.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$emoji $count', style: BuType.caption.copyWith(color: t.ink, fontWeight: mine ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

/// Gönderilmekte olan görselin yerel önizlemesi (üzerinde yükleme göstergesi).
class _LocalImage extends StatelessWidget {
  const _LocalImage({required this.bytes, required this.uploading, required this.maxW});

  final Uint8List bytes;
  final bool uploading;
  final double maxW;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(alignment: Alignment.center, children: [
        Image.memory(bytes,
            width: (maxW - 12).clamp(140.0, 300.0), height: 220, fit: BoxFit.cover, cacheWidth: 720, gaplessPlayback: true),
        if (uploading)
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            padding: const EdgeInsets.all(10),
            child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          ),
      ]),
    );
  }
}

String chatMediaUrl(String path) => path.startsWith('http') ? path : '$apiOrigin$path';

class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({
    required this.attachment,
    required this.headers,
    required this.maxW,
    required this.onTap,
    this.side,
    this.more = 0,
  });

  final Map<String, dynamic> attachment;
  final Map<String, String> headers;
  final double maxW;
  final VoidCallback onTap;

  /// Verilirse kare hücre (çoklu görsel ızgarası).
  final double? side;

  /// Izgarada gösterilmeyen görsel sayısı (son hücrede "+N").
  final int more;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final w = (attachment['width'] as num?)?.toDouble() ?? 0;
    final h = (attachment['height'] as num?)?.toDouble() ?? 0;
    // Görsel oranını koru (dikey/yatay), çok uzun görselleri sınırla.
    final ratio = (w > 0 && h > 0) ? (w / h).clamp(.55, 2.0) : 1.2;
    final width = side ?? maxW.clamp(140.0, 300.0);
    final height = side ?? (width / ratio).clamp(110.0, 380.0);
    final thumb = (attachment['thumbUrl'] ?? attachment['url']) as String?;
    final hidden = attachment['removed'] == true || thumb == null;

    Widget box(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(side != null ? 10 : 14),
          child: SizedBox(width: width, height: height, child: child),
        );

    if (hidden) {
      return box(ColoredBox(
        color: t.sf2,
        child: Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
      ));
    }
    return GestureDetector(
      onTap: onTap,
      child: box(Stack(fit: StackFit.expand, children: [
        Image.network(
          chatMediaUrl(thumb),
          headers: headers,
          fit: BoxFit.cover,
          cacheWidth: 720,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : ColoredBox(color: t.sf2, child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
          errorBuilder: (c, e, s) => ColoredBox(
            color: t.sf2,
            child: Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
          ),
        ),
        if (more > 0)
          ColoredBox(
            color: Colors.black.withValues(alpha: .5),
            child: Center(child: Text('+$more', style: BuType.title.copyWith(color: Colors.white))),
          ),
      ])),
    );
  }
}

/// Tam ekran görsel görüntüleyici (yakınlaştır / kaydır).
class ChatImageViewer extends StatelessWidget {
  const ChatImageViewer({super.key, required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kapat',
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.network(
            chatMediaUrl(url),
            headers: headers,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, p) =>
                p == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (c, e, s) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Görsel yüklenemedi.', style: BuType.body.copyWith(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Baloncuğu yatayda (en çok 64 dp) sürükleyip bırakınca yanıt tetikler; yön RTL'de tersine döner.
class _SwipeReply extends StatefulWidget {
  const _SwipeReply({required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<_SwipeReply> createState() => _SwipeReplyState();
}

class _SwipeReplyState extends State<_SwipeReply> with SingleTickerProviderStateMixin {
  static const _max = 64.0;
  static const _threshold = 48.0;

  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _p = 0; // 0.._max, sürükleme yönündeki ilerleme
  bool _armed = false;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() {
      if (mounted) setState(() => _p = (_from * (1 - Curves.easeOutCubic.transform(_back.value))).clamp(0.0, _max).toDouble());
    });
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  double _sign(BuildContext c) => Directionality.of(c) == TextDirection.rtl ? -1 : 1;

  void _update(DragUpdateDetails d) {
    _back.stop();
    final next = (_p + d.delta.dx * _sign(context)).clamp(0.0, _max).toDouble();
    if (!_armed && next >= _threshold) {
      _armed = true;
      HapticFeedback.lightImpact();
    } else if (_armed && next < _threshold) {
      _armed = false;
    }
    setState(() => _p = next);
  }

  void _end(DragEndDetails d) {
    final fire = _p >= _threshold;
    _armed = false;
    _from = _p;
    _back
      ..reset()
      ..forward();
    if (fire) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final sign = _sign(context);
    final k = (_p / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _end(DragEndDetails()),
      child: Stack(children: [
        if (_p > 0)
          Positioned.fill(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Opacity(
                opacity: k,
                child: Transform.scale(
                  scale: .5 + .5 * k,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                    child: Icon(LucideIcons.reply, size: 15, color: t.mut),
                  ),
                ),
              ),
            ),
          ),
        Transform.translate(offset: Offset(_p * sign, 0), child: widget.child),
      ]),
    );
  }
}
