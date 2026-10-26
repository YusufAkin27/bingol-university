import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final m = message;
    final deleted = m['deleted'] == true;
    final removed = m['removed'] == true;
    final state = m['_state'] as String?;
    final fg = mine ? t.onPr : t.ink;
    final d = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
    final reply = m['replyTo'] is Map ? Map<String, dynamic>.from(m['replyTo'] as Map) : null;
    final text = deleted ? 'Bu mesaj silindi' : (m['text'] as String?) ?? '';
    final maxW = MediaQuery.sizeOf(context).width * .72;
    final atts = (deleted || removed) ? const <Map<String, dynamic>>[] : _attachments(m);
    final localBytes = m['_bytes'] as Uint8List?;
    final hasMedia = atts.isNotEmpty || localBytes != null;
    final reactions = (m['reactions'] as List? ?? const []).whereType<Map>().toList();
    final myReaction = m['myReaction'] as String?;

    final meta = <String>[
      if (d != null) '${_two(d.hour)}:${_two(d.minute)}',
      if (m['edited'] == true && !deleted) 'düzenlendi',
      if (state == 'pending') 'gönderiliyor',
    ].join(' · ');

    final showText = text.isNotEmpty && !(hasMedia && (m['text'] as String? ?? '').isEmpty);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: EdgeInsets.symmetric(horizontal: hasMedia ? 6 : 14, vertical: hasMedia ? 6 : 10),
      decoration: BoxDecoration(
        color: mine ? t.pr : t.sf,
        border: mine ? null : Border.all(color: t.bd),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(mine ? 20 : 6),
          bottomRight: Radius.circular(mine ? 6 : 20),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (senderName != null)
          Padding(
            padding: EdgeInsets.fromLTRB(hasMedia ? 8 : 0, hasMedia ? 4 : 0, 0, 3),
            child: Text(senderName!, style: TextStyle(color: t.pr, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        if (reply != null && !deleted)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: mine ? Colors.white.withValues(alpha: .2) : Colors.black.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(replyName ?? 'Kullanıcı', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
              Text(reply['deleted'] == true ? 'Bu mesaj silindi' : (reply['text'] as String?) ?? '',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 12, height: 1.35)),
            ]),
          ),
        if (localBytes != null)
          _LocalImage(bytes: localBytes, uploading: state == 'pending', maxW: maxW)
        else
          for (final a in atts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _AttachmentImage(
                attachment: a,
                headers: authHeaders,
                maxW: maxW - 12,
                onTap: () => onOpenImage(a),
              ),
            ),
        if (showText)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hasMedia ? 8 : 0, vertical: hasMedia ? 2 : 0),
            child: Text(text,
                style: TextStyle(
                  color: (deleted || removed) ? fg.withValues(alpha: .7) : fg,
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: (deleted || removed) ? FontStyle.italic : FontStyle.normal,
                )),
          ),
        if (meta.isNotEmpty || (mine && seen))
          Padding(
            padding: EdgeInsets.fromLTRB(hasMedia ? 8 : 0, 4, hasMedia ? 8 : 0, hasMedia ? 2 : 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(meta, style: TextStyle(color: fg.withValues(alpha: .7), fontSize: 10)),
                if (mine && seen && state == null) ...[
                  const SizedBox(width: 4),
                  Icon(LucideIcons.checkCheck, size: 13, color: fg.withValues(alpha: .9)),
                  const SizedBox(width: 2),
                  Text('okundu', style: TextStyle(color: fg.withValues(alpha: .7), fontSize: 10)),
                ],
              ]),
            ),
          ),
      ]),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: state == 'pending' ? null : onMenu,
            onTap: state == 'failed' ? onMenu : null,
            child: bubble,
          ),
          if (reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final r in reactions)
                  _ReactionChip(
                    emoji: '${r['emoji']}',
                    count: (r['count'] as num?)?.toInt() ?? 0,
                    mine: myReaction == r['emoji'],
                    onTap: () => onReact('${r['emoji']}'),
                  ),
              ]),
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
                        style: TextStyle(color: t.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: mine ? t.pr.withValues(alpha: .12) : t.sf2,
          border: Border.all(color: mine ? t.pr : t.bd),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('$emoji $count', style: TextStyle(color: t.ink, fontSize: 12, fontWeight: FontWeight.w700)),
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
        Image.memory(bytes, width: maxW - 12, height: 200, fit: BoxFit.cover, cacheWidth: 480, gaplessPlayback: true),
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
  const _AttachmentImage({required this.attachment, required this.headers, required this.maxW, required this.onTap});

  final Map<String, dynamic> attachment;
  final Map<String, String> headers;
  final double maxW;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final w = (attachment['width'] as num?)?.toDouble() ?? 0;
    final h = (attachment['height'] as num?)?.toDouble() ?? 0;
    final ratio = (w > 0 && h > 0) ? (w / h).clamp(.6, 1.8) : 1.2;
    final width = maxW.clamp(120.0, 260.0);
    final height = width / ratio;
    final thumb = (attachment['thumbUrl'] ?? attachment['url']) as String?;
    final hidden = attachment['removed'] == true || thumb == null;

    Widget box(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
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
      child: box(Image.network(
        chatMediaUrl(thumb),
        headers: headers,
        fit: BoxFit.cover,
        cacheWidth: 520,
        gaplessPlayback: true,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : ColoredBox(color: t.sf2, child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
        errorBuilder: (c, e, s) => ColoredBox(
          color: t.sf2,
          child: Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
        ),
      )),
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
            errorBuilder: (c, e, s) => const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Görsel yüklenemedi.', style: TextStyle(color: Colors.white70)),
            ),
          ),
        ),
      ),
    );
  }
}
