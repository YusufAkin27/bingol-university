import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'bubble_text_meta.dart';
import 'chat_media.dart';

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
    this.onOpenViewOnce,
    this.onOpenGallery,
    this.highlight,
    this.onSenderTap,
  });

  final Map<String, dynamic> message;
  final bool mine;

  /// Grup sohbetinde gelen mesajın üstünde görünen ad (yoksa null).
  final String? senderName;

  /// Gönderen adına dokunma (profil açar); null ise ad etkileşimsiz.
  final VoidCallback? onSenderTap;
  final String? replyName;

  /// Giden mesaj karşı tarafça okundu mu.
  final bool seen;
  final Map<String, String> authHeaders;
  final VoidCallback onMenu;
  final VoidCallback onRetry;
  final void Function(Map<String, dynamic> attachment) onOpenImage;
  final void Function(String emoji) onReact;

  /// Çok öğeli mesajda dokunulan hücreden başlayan galeri (tüm medya, başlangıç indeksi).
  final void Function(List<Map<String, dynamic>> attachments, int index)? onOpenGallery;

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

  /// Alıcı açılmamış tek gösterimlik fotoğrafa dokununca (ek haritasıyla) çağrılır.
  final void Function(Map<String, dynamic> attachment)? onOpenViewOnce;

  /// Sohbet içi aramada vurgulanacak metin (null/boş: vurgu yok).
  final String? highlight;

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
    // Giden baloncuk açık kırmızımsı zemin (t.soft) üstünde t.ink: okundu tiki marka kırmızısı (t.pr)
    // olarak görünür kalır, iletildi/iletilmedi tikleri gri (t.mut) kalır.
    final fg = t.ink;
    final metaColor = t.mut;
    final d = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
    final reply = m['replyTo'] is Map
        ? Map<String, dynamic>.from(m['replyTo'] as Map)
        : null;
    final text = deleted ? 'Bu mesaj silindi' : (m['text'] as String?) ?? '';
    final maxW = MediaQuery.sizeOf(context).width * .78;
    final allAtts =
        (deleted || removed) ? const <Map<String, dynamic>>[] : _attachments(m);
    final localVideo = !deleted && !removed && m['_isVideo'] == true;
    // Tek gösterimlik ek (sunucudan ya da yerel bekleyen): önizleme ASLA çizilmez, yalnız kart.
    final onceAtt = allAtts.where(isViewOnceAttachment).firstOrNull;
    final localOnce = !deleted &&
        !removed &&
        m['_viewOnce'] == true &&
        state != null &&
        onceAtt == null;
    final hasOnce = onceAtt != null || localOnce;
    final atts = allAtts.where((a) => !isViewOnceAttachment(a)).toList();
    final localBytes = hasOnce ? null : m['_bytes'] as Uint8List?;
    final localItems = (hasOnce || deleted || removed)
        ? const <Map<String, dynamic>>[]
        : ((m['_localItems'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[]);
    final localGrid = localItems.length > 1;
    final hasMedia = atts.isNotEmpty || localBytes != null || localVideo || localGrid;
    final reactions =
        (m['reactions'] as List? ?? const []).whereType<Map>().toList();
    final myReaction = m['myReaction'] as String?;
    final showText = text.isNotEmpty &&
        !((hasMedia || hasOnce) && (m['text'] as String? ?? '').isEmpty);

    final metaText = [
      if (m['edited'] == true && !deleted) 'düzenlendi',
      if (d != null) '${_two(d.hour)}:${_two(d.minute)}',
    ].join(' · ');
    // Tik durumu: pending (saat) | SENT (tek tik) | DELIVERED (çift tik, gri) | READ (çift tik, kırmızı).
    final String? tick = !mine
        ? null
        : state == 'pending'
            ? 'pending'
            : state == 'failed'
                ? null
                : m['id'] == null
                    ? null
                    : (seen || m['status'] == 'READ')
                        ? 'READ'
                        : (m['status'] == 'DELIVERED' ? 'DELIVERED' : 'SENT');
    final hasMeta = metaText.isNotEmpty || tick != null;

    Widget metaRow(Color color, {Color? readColor}) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (metaText.isNotEmpty)
            Text(metaText, style: BuType.micro.copyWith(color: color)),
          if (tick != null) ...[
            const SizedBox(width: 3),
            _Tick(status: tick, color: color, readColor: readColor ?? t.pr),
          ],
        ]);

    final textStyle = BuType.body.copyWith(
      color: (deleted || removed) ? fg.withValues(alpha: .7) : fg,
      fontStyle: (deleted || removed) ? FontStyle.italic : FontStyle.normal,
    );

    // Saat+tik, metnin son satırında yer varsa aynı satırda, yoksa altında durur (bkz. BubbleTextMeta).
    final textSpan = _span(text, textStyle, highlight);
    Widget textWithMeta() {
      final tw = Text.rich(textSpan, textWidthBasis: TextWidthBasis.longestLine);
      if (!hasMeta) return tw;
      return BubbleTextMeta(text: tw, meta: metaRow(metaColor));
    }

    // Yalnız medya: saat+tik görselin sağ altında yarı saydam koyu hap (okundu tiki açık kırmızı).
    Widget mediaWithPill(Widget media) {
      if (showText || !hasMeta) return media;
      return Stack(children: [
        media,
        PositionedDirectional(
          end: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(999)),
            child: metaRow(Colors.white.withValues(alpha: .85),
                readColor: BuTokens.dark.pr),
          ),
        ),
      ]);
    }

    final w = (maxW - 12).clamp(140.0, 300.0);
    Widget? mediaBlock;
    if (localGrid) {
      mediaBlock = _LocalGrid(items: localItems, width: w, uploading: state == 'pending');
    } else if (localVideo || localBytes != null) {
      final vw = (m['_vw'] as num?)?.toDouble() ?? 0;
      final vh = (m['_vh'] as num?)?.toDouble() ?? 0;
      mediaBlock = _LocalMedia(
          bytes: localBytes,
          uploading: state == 'pending',
          maxW: maxW,
          video: localVideo,
          durationMs: (m['_durationMs'] as num?)?.toInt(),
          ratio: (vw > 0 && vh > 0) ? (vw / vh).clamp(.55, 2.0) : null,
          progress: m['_progress'] is ValueListenable<double>
              ? m['_progress'] as ValueListenable<double>
              : null);
    } else if (atts.length == 1) {
      mediaBlock = _AttachmentImage(
          attachment: atts.first,
          headers: authHeaders,
          maxW: maxW - 12,
          onTap: () => onOpenImage(atts.first));
    } else if (atts.length > 1) {
      final three = atts.length > 4;
      final cell = three ? (w - 8) / 3 : (w - 4) / 2;
      final cap = three ? 6 : 4;
      final shown = atts.take(cap).toList();
      void open(int i) => onOpenGallery != null ? onOpenGallery!(atts, i) : onOpenImage(atts[i]);
      mediaBlock = SizedBox(
        width: w,
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < shown.length; i++)
            _AttachmentImage(
              attachment: shown[i],
              headers: authHeaders,
              maxW: maxW - 12,
              side: cell,
              more: (i == cap - 1 && atts.length > cap) ? atts.length - cap + 1 : 0,
              onTap: () => open(i),
            ),
        ]),
      );
    }

    Widget? onceBlock;
    if (hasOnce) {
      final viewed = onceAtt?['viewed'] == true;
      final hasUrl = onceAtt?['url'] != null;
      final expired = viewed || (!mine && onceAtt != null && !hasUrl);
      final openable = !mine && onceAtt != null && !expired && hasUrl;
      onceBlock = ViewOnceCard(
        mine: mine,
        opened: expired,
        sending: localOnce && state == 'pending',
        onTap: openable && onOpenViewOnce != null && !preview
            ? () => onOpenViewOnce!(onceAtt)
            : null,
        meta: showText || !hasMeta ? null : metaRow(metaColor),
      );
    }

    const r = Radius.circular(18);
    const small = Radius.circular(5);
    final body = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: EdgeInsets.symmetric(
          horizontal: hasMedia ? 6 : 14, vertical: hasMedia ? 6 : 9),
      decoration: BoxDecoration(
        color: mine ? t.soft : t.sf,
        // Mantıksal köşeler: sağdan sola düzende kuyruk köşesi de aynalanır.
        borderRadius: BorderRadiusDirectional.only(
          topStart: r,
          topEnd: r,
          bottomStart: (mine || !tail) ? r : small,
          bottomEnd: (mine && tail) ? small : r,
        ),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (senderName != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    hasMedia ? 8 : 0, hasMedia ? 4 : 0, 0, 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: preview ? null : onSenderTap,
                  child: Text(senderName!,
                      style: BuType.label.copyWith(color: t.pr)),
                ),
              ),
            if (reply != null && !deleted) _quote(context, t, reply, fg),
            if (onceBlock != null)
              Padding(
                padding: EdgeInsets.only(bottom: showText ? 6 : 0),
                child: onceBlock,
              ),
            if (mediaBlock != null)
              Padding(
                padding: EdgeInsets.only(bottom: showText ? 4 : 0),
                child: mediaWithPill(mediaBlock),
              ),
            if (showText)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: hasMedia ? 8 : 0, vertical: hasMedia ? 2 : 0),
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
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                  Icon(LucideIcons.circleAlert, size: 12.5, color: t.danger),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                        '${(m['_error'] as String?) ?? 'Gönderilemedi'} · Yeniden dene',
                        style: BuType.micro.copyWith(
                            color: t.danger, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
    return onSwipeReply == null
        ? column
        : _SwipeReply(onReply: onSwipeReply!, child: column);
  }

  /// Yanıt alıntısı: solda renkli ince çizgi (kendi mesajım / başkasınınki).
  Widget _quote(BuildContext context, BuTokens t, Map<String, dynamic> reply, Color fg) {
    final bar = replyMine ? t.pr : t.ok;
    final raw = reply['deleted'] == true
        ? 'Bu mesaj silindi'
        : (reply['text'] as String?) ?? '';
    final quoted = raw.isEmpty
        ? (reply['kind'] == 'VIDEO' ? 'Video' : 'Fotoğraf')
        : raw;
    final box = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: .07)
            : Colors.black.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 3, color: bar),
              Flexible(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(replyName ?? 'Kullanıcı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BuType.micro.copyWith(
                                color: fg, fontWeight: FontWeight.w700)),
                        Text(quoted,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: BuType.caption
                                .copyWith(color: fg.withValues(alpha: .9))),
                      ]),
                ),
              ),
            ]),
      ),
    );
    return onReplyTap == null
        ? box
        : GestureDetector(onTap: onReplyTap, child: box);
  }

  /// Metin aralığı: [highlight] eşleşmeleri (büyük/küçük harf duyarsız) sarı zeminle vurgulanır.
  static TextSpan _span(String text, TextStyle style, String? highlight) {
    final q = highlight?.trim().toLowerCase() ?? '';
    if (q.isEmpty || text.isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    // toLowerCase uzunluğu değiştirirse (ör. İ) güvenli yola dön.
    if (lower.length != text.length) return TextSpan(text: text, style: style);
    final hl = style.copyWith(
        backgroundColor: const Color(0xFFFFD54F), color: Colors.black87);
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final j = lower.indexOf(q, i);
      if (j < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (j > i) spans.add(TextSpan(text: text.substring(i, j)));
      spans.add(TextSpan(text: text.substring(j, j + q.length), style: hl));
      i = j + q.length;
    }
    return TextSpan(style: style, children: spans);
  }

  static List<Map<String, dynamic>> _attachments(Map<String, dynamic> m) =>
      (m['attachments'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip(
      {required this.emoji,
      required this.count,
      required this.mine,
      required this.onTap});

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
          color:
              mine ? Color.alphaBlend(t.pr.withValues(alpha: .14), t.sf) : t.sf,
          border: Border.all(color: mine ? t.pr : t.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$emoji $count',
            style: BuType.caption.copyWith(
                color: t.ink,
                fontWeight: mine ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}

/// Saat+durum ikonu. Durum değişince hafif çapraz geçişle yenilenir.
/// pending: saat; SENT: tek tik; DELIVERED: çift tik; READ: çift tik ([readColor], marka kırmızısı).
class _Tick extends StatelessWidget {
  const _Tick(
      {required this.status, required this.color, required this.readColor});

  final String status;
  final Color color;
  final Color readColor;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      'pending' => LucideIcons.clock,
      'SENT' => LucideIcons.check,
      _ => LucideIcons.checkCheck,
    };
    final label = switch (status) {
      'pending' => 'Gönderiliyor',
      'SENT' => 'Gönderildi',
      'DELIVERED' => 'İletildi',
      _ => 'Okundu',
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 16,
          height: 14,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Icon(icon,
                key: ValueKey<String>(status),
                size: 12.5,
                color: status == 'READ' ? readColor : color),
          ),
        ),
      ),
    );
  }
}

/// Oynat simgesi: yarı saydam koyu daire içinde.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5), shape: BoxShape.circle),
      child: Icon(LucideIcons.play,
          size: size * .45, color: Colors.white),
    );
  }
}

/// Video süresi hapı (örn. "0:42"), küçük video simgesiyle.
class DurationPill extends StatelessWidget {
  const DurationPill({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.video, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(formatMediaDuration(ms),
            style: BuType.micro.copyWith(color: Colors.white)),
      ]),
    );
  }
}

/// Gönderilmekte olan görsel/videonun yerel önizlemesi (üzerinde yükleme göstergesi; video için
/// poster + dairesel ilerleme + süre hapı).
class _LocalMedia extends StatelessWidget {
  const _LocalMedia({
    required this.bytes,
    required this.uploading,
    required this.maxW,
    this.video = false,
    this.durationMs,
    this.ratio,
    this.progress,
  });

  final Uint8List? bytes;
  final bool uploading;
  final double maxW;
  final bool video;
  final int? durationMs;
  final double? ratio;
  final ValueListenable<double>? progress;

  @override
  Widget build(BuildContext context) {
    final width = (maxW - 12).clamp(140.0, 300.0);
    final height =
        video && ratio != null ? (width / ratio!).clamp(110.0, 380.0) : 220.0;
    Widget spinner() {
      final p = progress;
      Widget ring(double? v) => SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                value: v, strokeWidth: 2.5, color: Colors.white),
          );
      return Container(
        key: const ValueKey('uploadProgress'),
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
            color: Colors.black54, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: p == null
            ? ring(null)
            : ValueListenableBuilder<double>(
                valueListenable: p,
                builder: (c, v, _) => ring(v > 0 && v < 1 ? v : null)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
          if (bytes != null)
            Image.memory(bytes!,
                fit: BoxFit.cover, cacheWidth: 720, gaplessPlayback: true)
          else
            const ColoredBox(color: Colors.black87),
          Center(
              child: uploading
                  ? spinner()
                  : (video ? const PlayBadge() : const SizedBox.shrink())),
          if (video && durationMs != null)
            PositionedDirectional(
                start: 6, bottom: 6, child: DurationPill(ms: durationMs!)),
        ]),
      ),
    );
  }
}

/// Gönderilmekte olan çok öğeli mesajın yerel ızgarası (2: yan yana, 3-4: 2 sütun, 5-10: 3 sütun, en çok 6 hücre).
class _LocalGrid extends StatelessWidget {
  const _LocalGrid({required this.items, required this.width, required this.uploading});

  final List<Map<String, dynamic>> items;
  final double width;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final three = items.length > 4;
    final cell = three ? (width - 8) / 3 : (width - 4) / 2;
    final cap = three ? 6 : 4;
    final shown = items.take(cap).toList();
    final extra = items.length > cap ? items.length - cap + 1 : 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: width,
        child: Stack(alignment: Alignment.center, children: [
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (var i = 0; i < shown.length; i++)
              SizedBox(
                width: cell,
                height: cell,
                child: Stack(fit: StackFit.expand, children: [
                  if (shown[i]['bytes'] is Uint8List)
                    Image.memory(shown[i]['bytes'] as Uint8List,
                        fit: BoxFit.cover, cacheWidth: 360, gaplessPlayback: true)
                  else
                    const ColoredBox(color: Colors.black87),
                  if (shown[i]['video'] == true && !(i == cap - 1 && extra > 0))
                    const Center(child: PlayBadge(size: 30)),
                  if (i == cap - 1 && extra > 0)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: .5),
                      child: Center(
                          child: Text('+$extra', textDirection: TextDirection.ltr, style: BuType.title.copyWith(color: Colors.white))),
                    ),
                ]),
              ),
          ]),
          if (uploading)
            Container(
              key: const ValueKey('uploadProgress'),
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}

String chatMediaUrl(String path) =>
    path.startsWith('http') ? path : '$apiOrigin$path';

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
    final video = isVideoAttachment(attachment);
    // Videoda `url` akış adresidir (görsel değil): önizleme yalnız `thumbUrl` (poster) olabilir.
    final thumb = (video
        ? attachment['thumbUrl']
        : (attachment['thumbUrl'] ?? attachment['url'])) as String?;
    final hidden = attachment['removed'] == true || (thumb == null && !video);
    final durationMs = (attachment['durationMs'] as num?)?.toInt();

    Widget box(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(side != null ? 10 : 14),
          child: SizedBox(width: width, height: height, child: child),
        );

    if (hidden) {
      return Semantics(
        label: 'Görsel kullanılamıyor',
        excludeSemantics: true,
        child: box(ColoredBox(
          color: t.sf2,
          child: Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
        )),
      );
    }
    return Semantics(
      button: true,
      image: true,
      excludeSemantics: true,
      label: video
          ? (durationMs != null ? 'Video, ${formatMediaDuration(durationMs)}' : 'Video')
          : 'Fotoğraf',
      onTap: onTap,
      child: GestureDetector(
      onTap: onTap,
      child: box(Stack(fit: StackFit.expand, children: [
        if (thumb == null)
          const ColoredBox(color: Colors.black87)
        else
          Image.network(
          chatMediaUrl(thumb),
          headers: headers,
          fit: BoxFit.cover,
          cacheWidth: 720,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : ColoredBox(
                  color: t.sf2,
                  child: const Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2)))),
          errorBuilder: (c, e, s) => ColoredBox(
            color: t.sf2,
            // Videoda oynat simgesi zaten ortada: kırık görsel simgesi onunla üst üste binmesin.
            child: video ? null : Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
          ),
        ),
        if (video && more == 0) ...[
          Center(child: PlayBadge(size: side != null ? 34 : 46)),
          if (durationMs != null)
            PositionedDirectional(
                start: 6, bottom: 6, child: DurationPill(ms: durationMs)),
        ],
        if (more > 0)
          ColoredBox(
            color: Colors.black.withValues(alpha: .5),
            child: Center(
                child: Text('+$more', textDirection: TextDirection.ltr,
                    style: BuType.title.copyWith(color: Colors.white))),
          ),
      ])),
    ));
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
            loadingBuilder: (c, child, p) => p == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (c, e, s) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Görsel yüklenemedi.',
                  style: BuType.body.copyWith(color: Colors.white70)),
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

class _SwipeReplyState extends State<_SwipeReply>
    with SingleTickerProviderStateMixin {
  static const _max = 64.0;
  static const _threshold = 48.0;

  late final AnimationController _back = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  double _p = 0; // 0.._max, sürükleme yönündeki ilerleme
  bool _armed = false;
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() {
      if (mounted) {
        setState(() => _p =
            (_from * (1 - Curves.easeOutCubic.transform(_back.value)))
                .clamp(0.0, _max)
                .toDouble());
      }
    });
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  double _sign(BuildContext c) =>
      Directionality.of(c) == TextDirection.rtl ? -1 : 1;

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
                    decoration:
                        BoxDecoration(color: t.sf2, shape: BoxShape.circle),
                    child: Icon(LucideIcons.reply, size: 13.5, color: t.mut),
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

/// Tek gösterimlik fotoğraf kartı: gerçek önizleme yoktur, yalnız durum gösterilir.
/// Açılmamış (alıcı): "1" halkası marka renginde; açılmış: soluk, kesikli halka.
class ViewOnceCard extends StatelessWidget {
  const ViewOnceCard(
      {super.key,
      required this.mine,
      required this.opened,
      this.sending = false,
      this.onTap,
      this.meta});

  final bool mine;
  final bool opened;
  final bool sending;
  final VoidCallback? onTap;

  /// Saat/durum satırı (yalnız metin yokken kartın içinde sağ altta).
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    // Giden baloncuk artık açık zeminli (t.soft): her iki yönde yazı t.ink, vurgu marka kırmızısı.
    final base = t.ink;
    final Color accent = opened ? base.withValues(alpha: .55) : t.pr;
    final String label = opened
        ? 'Açıldı'
        : mine
            ? (sending ? 'Fotoğraf · Gönderiliyor' : 'Fotoğraf · Gönderildi')
            : 'Fotoğraf · Açmak için dokun';
    final labelColor = opened ? base.withValues(alpha: .6) : t.pr;
    final card = Semantics(
      button: onTap != null,
      label: 'Tek gösterimlik fotoğraf. $label',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
        child: IntrinsicWidth(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  OnceBadge(color: accent, dashed: opened),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.label.copyWith(
                            color: labelColor,
                            fontStyle:
                                opened ? FontStyle.italic : FontStyle.normal)),
                  ),
                ]),
                if (meta != null)
                  Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                          padding: const EdgeInsets.only(top: 2), child: meta)),
              ]),
        ),
      ),
    );
    return onTap == null
        ? card
        : GestureDetector(
            key: const ValueKey('viewOnceCard'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: card);
  }
}

/// İçinde "1" yazan yuvarlak (tek gösterimlik simgesi); [dashed] iken kesikli çizgi.
class OnceBadge extends StatelessWidget {
  const OnceBadge(
      {super.key, required this.color, this.dashed = false, this.size = 28});

  final Color color;
  final bool dashed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(color, dashed),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
            child: Text('1',
                style: BuType.label.copyWith(
                    color: color, fontWeight: FontWeight.w800, height: 1))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final r = (Offset.zero & size).deflate(1.5);
    if (!dashed) {
      canvas.drawOval(r, paint);
      return;
    }
    const n = 12;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(r, i * 2 * math.pi / n, math.pi / n, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.dashed != dashed;
}
