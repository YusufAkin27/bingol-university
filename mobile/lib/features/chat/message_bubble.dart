import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'bubble_text_meta.dart';
import 'chat_media.dart';
import 'chat_media_parts.dart';
import 'chatd_parts.dart';
import 'message_placeholder.dart';

// Eski içe aktarmalar `message_bubble.dart` üzerinden `chatMediaUrl` alıyor.
export 'chat_media.dart' show chatMediaUrl;

String _two(int n) => n.toString().padLeft(2, '0');

/// Medya baloncuğunun kenarı (dp): SABİT KARE ~224 (kullanıcı kararı 2026-10-30), dar ekranda sınırlı; bkz. [chatMediaSide].
double _mediaWidth(double maxW) => chatMediaSide(maxW);

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
    this.highlighted = false,
  });

  /// Arama/alıntı atlama vurgusu: baloncuğun çevresine 2 dp marka rengi çerçeve çizer.
  final bool highlighted;

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
    final tx = Theme.of(context).textTheme;
    final m = message;
    final deleted = m['deleted'] == true;
    final removed = m['removed'] == true;
    final state = m['_state'] as String?;
    final ghost = deleted || removed;
    final adminRemoved = ghost && isAdminRemovedText(m['text'] as String?);
    final failed = state == 'failed';
    // Giden baloncuk marka kırmızısı (t.pr) üstünde t.onPr; gelen baloncuk yüzey (t.sf). Silinen/kaldırılan:
    // soluk zemin; gönderilemedi: yumuşak kırmızı. Çevrimdışı kuyruktaki mesaj normal "gönderiliyor" görünür.
    final Color bodyColor;
    final Color fg;
    if (ghost) {
      bodyColor = adminRemoved ? t.soft : t.sf2;
      fg = adminRemoved ? t.onSoft : t.mut;
    } else if (mine && failed) {
      bodyColor = t.soft;
      fg = t.onSoft;
    } else {
      bodyColor = mine ? t.pr : t.sf;
      fg = mine ? t.onPr : t.ink;
    }
    final solidMine = mine && !ghost && !failed;
    final metaColor = solidMine ? t.onPr.withValues(alpha: .75) : (adminRemoved ? t.onSoft.withValues(alpha: .8) : t.mut);
    final d = DateTime.tryParse((m['createdAt'] as String?) ?? '')?.toLocal();
    final reply = m['replyTo'] is Map ? Map<String, dynamic>.from(m['replyTo'] as Map) : null;
    // Silinen/gizlenen/yönetici kaldırması: sunucunun sabit Türkçe metni yerine uygulama dilinde yer tutucu.
    final text = (deleted || removed)
        ? removedPlaceholder(context, serverText: m['text'] as String?, deleted: deleted, removed: removed)
        : (m['text'] as String?) ?? '';
    final maxW = MediaQuery.sizeOf(context).width * .78;
    final allAtts = (deleted || removed) ? const <Map<String, dynamic>>[] : _attachments(m);
    final localVideo = !deleted && !removed && m['_isVideo'] == true;
    // Tek gösterimlik ek (sunucudan ya da yerel bekleyen): önizleme ASLA çizilmez, yalnız kart.
    final onceAtt = allAtts.where(isViewOnceAttachment).firstOrNull;
    final localOnce = !deleted && !removed && m['_viewOnce'] == true && state != null && onceAtt == null;
    final hasOnce = onceAtt != null || localOnce;
    // Açılmamış, alıcıda açılabilir tek gösterimlik: koyu "Görüntüle" kartı (medya balonu). Diğer durumlar hap.
    final onceViewed = onceAtt?['viewed'] == true;
    final onceHasUrl = onceAtt?['url'] != null;
    final onceLocked = !mine && onceAtt != null && !onceViewed && onceHasUrl;
    final atts = allAtts.where((a) => !isViewOnceAttachment(a)).toList();
    final localBytes = hasOnce ? null : m['_bytes'] as Uint8List?;
    final localItems = (hasOnce || deleted || removed)
        ? const <Map<String, dynamic>>[]
        : ((m['_localItems'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[]);
    final localGrid = localItems.length > 1;
    final hasMedia = atts.isNotEmpty || localBytes != null || localVideo || localGrid;
    final reactions = (m['reactions'] as List? ?? const []).whereType<Map>().toList();
    final myReaction = m['myReaction'] as String?;
    final showText = text.isNotEmpty && !((hasMedia || hasOnce) && (m['text'] as String? ?? '').isEmpty);

    final metaText = [
      if (m['edited'] == true && !deleted) context.l10n.chatMiscEdited,
      if (d != null) '${_two(d.hour)}:${_two(d.minute)}',
    ].join(' · ');
    // Tik durumu: pending (saat) | SENT (tek tik) | DELIVERED (çift tik, gri) | READ (çift tik, kırmızı).
    final String? tick = (!mine || ghost)
        ? null
        : state == 'pending'
            ? 'pending'
            : state == 'failed'
                ? 'failed'
                : m['id'] == null
                    ? null
                    : (seen || m['status'] == 'READ')
                        ? 'READ'
                        : (m['status'] == 'DELIVERED' ? 'DELIVERED' : 'SENT');
    final hasMeta = metaText.isNotEmpty || tick != null;
    final mediaStyle = hasMedia || onceLocked;

    Widget metaRow(Color color, {Color? readColor}) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (metaText.isNotEmpty) Text(metaText, style: tx.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w500)),
          if (tick != null) ...[
            const SizedBox(width: 4),
            _Tick(status: tick, color: color, readColor: readColor ?? (solidMine ? t.onPr : t.pr), failedColor: t.danger),
          ],
        ]);

    final textStyle = tx.bodyLarge!.copyWith(
      color: fg,
      fontStyle: ghost ? FontStyle.italic : FontStyle.normal,
    );

    // Saat+tik, metnin son satırında yer varsa aynı satırda, yoksa altında durur (bkz. BubbleTextMeta).
    final textSpan = _span(text, textStyle, highlight, t.warnSoft, t.onWarnSoft);
    Widget textWithMeta() {
      final tw = Text.rich(textSpan, textWidthBasis: TextWidthBasis.longestLine);
      final inner = hasMeta ? BubbleTextMeta(text: tw, meta: metaRow(metaColor)) : tw;
      if (!ghost) return inner;
      // Silinen/kaldırılan: solda küçük simge (metin düz kalır, böylece metin aramaları bozulmaz).
      return Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6, top: 3),
          child: Icon(adminRemoved ? LucideIcons.shieldAlert : LucideIcons.ban, size: 15, color: fg),
        ),
        Flexible(child: inner),
      ]);
    }

    // Yalnız medya: saat+tik görselin sağ altında yarı saydam koyu hap (okundu tiki de açık renk).
    Widget mediaWithPill(Widget media) {
      if (showText || !hasMeta || (atts.length == 1 && localBytes == null && !localVideo && !localGrid)) return media;
      return Stack(children: [
        media,
        PositionedDirectional(
          end: 8,
          bottom: 8,
          child: ChatdPill(child: metaRow(t.onMedia, readColor: t.onMedia)),
        ),
      ]);
    }

    final w = _mediaWidth(maxW);
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
          progress: m['_progress'] is ValueListenable<double> ? m['_progress'] as ValueListenable<double> : null);
    } else if (atts.length == 1) {
      mediaBlock = _AttachmentImage(
        attachment: atts.first,
        headers: authHeaders,
        maxW: w,
        placeholder: m['_ph'] as Uint8List?,
        radius: BorderRadius.zero,
        onTap: () => onOpenImage(atts.first),
        overlay: (!showText && hasMeta)
            ? PositionedDirectional(end: 8, bottom: 8, child: ChatdPill(child: metaRow(t.onMedia, readColor: t.onMedia)))
            : null,
      );
    } else if (atts.length > 1) {
      final cols = atts.length > 4 ? 3 : 2;
      final cap = cols == 3 ? 6 : 4;
      final cell = (w - 3 * (cols - 1)) / cols;
      final shown = atts.take(cap).toList();
      void open(int i) => onOpenGallery != null ? onOpenGallery!(atts, i) : onOpenImage(atts[i]);
      mediaBlock = SizedBox(
        width: w,
        child: Wrap(spacing: 3, runSpacing: 3, children: [
          for (var i = 0; i < shown.length; i++)
            _AttachmentImage(
              attachment: shown[i],
              headers: authHeaders,
              maxW: w,
              side: cell,
              sideH: cell,
              radius: chatdCellRadius(i, cols, shown.length),
              more: (i == cap - 1 && atts.length > cap) ? atts.length - cap + 1 : 0,
              onTap: () => open(i),
            ),
        ]),
      );
    }

    Widget? onceBlock;
    if (hasOnce) {
      final expired = onceViewed || (!mine && onceAtt != null && !onceHasUrl);
      onceBlock = ViewOnceCard(
        mine: mine,
        opened: expired,
        sending: localOnce && state == 'pending',
        onTap: onceLocked && onOpenViewOnce != null && !preview ? () => onOpenViewOnce!(onceAtt) : null,
        meta: showText || !hasMeta ? null : metaRow(onceLocked ? t.onMedia : (solidMine ? t.onSoft.withValues(alpha: .8) : metaColor), readColor: onceLocked ? t.onMedia : (solidMine ? t.pr : null)),
      );
    }

    final r = Radius.circular(mediaStyle ? 22 : 20);
    const small = Radius.circular(6);
    // Hap tek gösterimlik durumları (Açıldı/Gönderildi): gelen soluk zemin, giden kırmızı.
    final oncePill = hasOnce && !onceLocked;
    final softPill = oncePill && solidMine;
    final nameWidget = senderName == null
        ? null
        : Padding(
            padding: EdgeInsetsDirectional.fromSTEB(mediaStyle ? 6 : 0, 0, 0, mediaStyle ? 4 : 3),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: preview ? null : onSenderTap,
              child: Text(senderName!,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: t.tint(senderName.hashCode).fg, fontWeight: FontWeight.w700)),
            ),
          );
    final core = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      clipBehavior: mediaStyle ? Clip.antiAlias : Clip.none,
      padding: EdgeInsets.symmetric(horizontal: mediaStyle ? 0 : 14, vertical: mediaStyle ? 0 : 9),
      decoration: BoxDecoration(
        color: onceLocked ? BuTokens.light.ink : (softPill ? t.soft : (oncePill && !mine && !ghost ? t.sf2 : bodyColor)),
        border: highlighted ? Border.all(color: t.pr, width: 2) : ((mine || ghost) ? null : Border.all(color: t.bd)),
        // Mantıksal köşeler: sağdan sola düzende kuyruk köşesi de aynalanır.
        borderRadius: BorderRadiusDirectional.only(
          topStart: r,
          topEnd: r,
          bottomStart: (mine || !tail) ? r : small,
          bottomEnd: (mine && tail) ? small : r,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (nameWidget != null && !mediaStyle) nameWidget,
        if (adminRemoved)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(context.l10n.p08ModerationTitle, style: tx.labelMedium!.copyWith(color: t.danger, fontWeight: FontWeight.w700)),
          ),
        if (reply != null && !deleted)
          mediaStyle ? Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: _quote(context, t, reply, fg)) : _quote(context, t, reply, fg),
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
            padding: EdgeInsetsDirectional.fromSTEB(mediaStyle ? 10 : 0, mediaStyle ? 6 : 0, mediaStyle ? 10 : 0, mediaStyle ? 4 : 0),
            // Medya varken açıklama görselin genişliğini aşmasın: görsel balona kenardan kenara otursun.
            child: hasMedia ? ConstrainedBox(constraints: BoxConstraints(maxWidth: _mediaWidth(maxW) - 20), child: textWithMeta()) : textWithMeta(),
          ),
      ]),
    );

    final body = (mediaStyle && nameWidget != null)
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [nameWidget, core])
        : core;
    if (preview) return body;

    final gestureBubble = Builder(
      builder: (bc) => BuPressable(
        scale: .985,
        onLongPress: state == 'pending' ? null : () => _openMenu(bc),
        onTap: state == null || state == 'failed' ? () => _openMenu(bc) : null,
        child: body,
      ),
    );

    final column = Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
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
                offset: const Offset(0, -6),
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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.refreshCw, size: 13, color: t.danger),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(context.l10n.chatMiscSendFailedRetry((m['_error'] as String?) ?? context.l10n.chatMiscSendFailed),
                        style: tx.labelSmall!.copyWith(color: t.danger, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: t.danger)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
    return onSwipeReply == null ? column : _SwipeReply(onReply: onSwipeReply!, child: column);
  }

  /// Yanıt alıntısı: başta renkli ince çizgi (kendi mesajım / başkasınınki), tonal zemin.
  Widget _quote(BuildContext context, BuTokens t, Map<String, dynamic> reply, Color fg) {
    final tx = Theme.of(context).textTheme;
    final bar = mine ? fg : (replyMine ? t.pr : t.ok);
    final raw = reply['deleted'] == true
        ? removedPlaceholder(context, serverText: reply['text'] as String?, deleted: true, removed: true)
        : (reply['text'] as String?) ?? '';
    final quoted = raw.isEmpty ? (reply['kind'] == 'VIDEO' ? context.l10n.chatMiscVideo : context.l10n.chatMiscPhoto) : raw;
    final box = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: mine ? t.scrim.withValues(alpha: .18) : t.sf2,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(width: 3, color: bar),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(replyName ?? context.l10n.chatMiscUser,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelMedium!.copyWith(color: mine ? fg : bar, fontWeight: FontWeight.w700)),
                Text(quoted, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: fg.withValues(alpha: .88))),
              ]),
            ),
          ),
        ]),
      ),
    );
    return onReplyTap == null ? box : GestureDetector(onTap: onReplyTap, child: box);
  }

  /// Metin aralığı: [highlight] eşleşmeleri (büyük/küçük harf duyarsız) uyarı tonuyla vurgulanır.
  static TextSpan _span(String text, TextStyle style, String? highlight, Color hlBg, Color hlFg) {
    final q = highlight?.trim().toLowerCase() ?? '';
    if (q.isEmpty || text.isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    // toLowerCase uzunluğu değiştirirse (ör. İ) güvenli yola dön.
    if (lower.length != text.length) return TextSpan(text: text, style: style);
    final hl = style.copyWith(backgroundColor: hlBg, color: hlFg, fontWeight: FontWeight.w700);
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
    final tx = Theme.of(context).textTheme;
    // Görsel hap küçük; dokunma alanı dikeyde 8 dp genişletilir.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        buHaptic(BuHaptic.selection);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: mine ? t.soft : t.sf,
            border: Border.all(color: mine ? t.pr : t.bd, width: mine ? 1.4 : 1),
            borderRadius: BuRadius.bPill,
          ),
          child: Text('$emoji $count', textAlign: TextAlign.center, style: tx.labelMedium!.copyWith(color: mine ? t.onSoft : t.ink, fontWeight: mine ? FontWeight.w700 : FontWeight.w600)),
        ),
      ),
    );
  }
}

/// Saat+durum ikonu. Durum değişince hafif çapraz geçişle yenilenir.
/// pending: saat; SENT: tek tik; DELIVERED: çift tik; READ: çift tik ([readColor], marka kırmızısı).
class _Tick extends StatelessWidget {
  const _Tick({required this.status, required this.color, required this.readColor, required this.failedColor});

  final String status;
  final Color color;
  final Color readColor;
  final Color failedColor;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      'pending' => LucideIcons.clock,
      'failed' => LucideIcons.circleAlert,
      'SENT' => LucideIcons.check,
      _ => LucideIcons.checkCheck,
    };
    final label = switch (status) {
      'pending' => context.l10n.chatMiscStatusSending,
      'failed' => context.l10n.chatMiscSendFailed,
      'SENT' => context.l10n.chatMiscStatusSent,
      'DELIVERED' => context.l10n.chatMiscStatusDelivered,
      _ => context.l10n.chatMiscStatusRead,
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 16,
          height: 14,
          child: AnimatedSwitcher(
            duration: BuMotion.of(context, const Duration(milliseconds: 220)),
            child: Icon(icon, key: ValueKey<String>(status), size: 13, color: status == 'READ' ? readColor : (status == 'failed' ? failedColor : color)),
          ),
        ),
      ),
    );
  }
}

/// Oynat simgesi: yarı saydam koyu daire içinde.
class PlayBadge extends StatelessWidget {
  const PlayBadge({super.key, this.size = 46, this.chatd = false});

  final double size;

  /// Sohbet detay tasarımı (balonlarda): koyu daire + ince açık halka. Her iki kip artık aynı görünür.
  final bool chatd;

  @override
  Widget build(BuildContext context) => ChatdPlay(size: size);
}

/// Video süresi hapı (örn. "0:42"), küçük video simgesiyle.
class DurationPill extends StatelessWidget {
  const DurationPill({super.key, required this.ms});

  final int ms;

  @override
  Widget build(BuildContext context) => ChatdDuration(ms: ms);
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
    final t = context.bu;
    final width = _mediaWidth(maxW);
    final height = width; // sabit kare
    final decodeW = (width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(160, 1600);
    Widget spinner() {
      final p = progress;
      if (p == null) {
        return ChatdRing(key: const ValueKey('uploadProgress'), icon: LucideIcons.arrowUp, arc: t.pr, semantics: context.l10n.chatMiscStatusSending);
      }
      return ValueListenableBuilder<double>(
          valueListenable: p,
          builder: (c, v, _) => ChatdRing(
              key: const ValueKey('uploadProgress'), value: v > 0 && v < 1 ? v : null, icon: LucideIcons.arrowUp, arc: t.pr, semantics: context.l10n.chatMiscStatusSending));
    }

    // Yükleme etiketi: ilerleme biliniyorsa yüzde ("%65"), yoksa "Gönderiliyor…".
    Widget label() {
      final p = progress;
      if (p == null) return ChatdPill(child: Text(context.l10n.chatdSendingMedia));
      return ValueListenableBuilder<double>(
          valueListenable: p,
          builder: (c, v, _) => ChatdPill(
              child: Text(v > 0 && v < 1 ? context.l10n.p08Percent('${(v * 100).round()}') : context.l10n.chatdSendingMedia, textDirection: TextDirection.ltr)));
    }

    return ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
          if (bytes != null) Image.memory(bytes!, fit: BoxFit.cover, cacheWidth: decodeW, filterQuality: FilterQuality.medium, gaplessPlayback: true) else ColoredBox(color: t.sf2),
          if (uploading) ColoredBox(color: t.scrim.withValues(alpha: .34)) else if (video) ColoredBox(color: t.scrim.withValues(alpha: .14)),
          Center(
            child: uploading
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    spinner(),
                    const SizedBox(height: 8),
                    label(),
                  ])
                : (video ? const PlayBadge() : const SizedBox.shrink()),
          ),
          if (video && durationMs != null) PositionedDirectional(top: 8, start: 8, child: ChatdDuration(ms: durationMs!)),
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
    final t = context.bu;
    final cols = items.length > 4 ? 3 : 2;
    final cap = cols == 3 ? 6 : 4;
    final cell = (width - 3 * (cols - 1)) / cols;
    final shown = items.take(cap).toList();
    final extra = items.length > cap ? items.length - cap + 1 : 0;
    return SizedBox(
      width: width,
      child: Stack(alignment: Alignment.center, children: [
        Wrap(spacing: 3, runSpacing: 3, children: [
          for (var i = 0; i < shown.length; i++)
            ClipRRect(
              borderRadius: chatdCellRadius(i, cols, shown.length),
              child: SizedBox(
                width: cell,
                height: cell,
                child: Stack(fit: StackFit.expand, children: [
                  if (shown[i]['bytes'] is Uint8List)
                    Image.memory(shown[i]['bytes'] as Uint8List, fit: BoxFit.cover, cacheWidth: (cell * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(160, 1600), filterQuality: FilterQuality.medium, gaplessPlayback: true)
                  else
                    ColoredBox(color: t.sf2),
                  if (uploading) ColoredBox(color: t.scrim.withValues(alpha: .3)),
                  if (shown[i]['video'] == true && !(i == cap - 1 && extra > 0)) const Center(child: ChatdPlay(size: 30)),
                  if (i == cap - 1 && extra > 0)
                    ColoredBox(
                      color: t.scrim.withValues(alpha: .55),
                      child: Center(
                        child: Text('+$extra', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: t.onMedia)),
                      ),
                    ),
                ]),
              ),
            ),
        ]),
        if (uploading) const ChatdRing(key: ValueKey('uploadProgress'), icon: LucideIcons.arrowUp),
      ]),
    );
  }
}

class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({
    required this.attachment,
    required this.headers,
    required this.maxW,
    required this.onTap,
    this.side,
    this.sideH,
    this.radius,
    this.more = 0,
    this.overlay,
    this.placeholder,
  });

  /// Gönderenin yerel (hazırlanmış) görsel baytları: sunucu görseli gelene dek altta durur.
  final Uint8List? placeholder;

  /// Görsel yüklendikten (ya da hata verdikten) sonra üstüne bindirilen öğe (saat hapı).
  final Widget? overlay;

  final Map<String, dynamic> attachment;
  final Map<String, String> headers;
  final double maxW;
  final VoidCallback onTap;

  /// Verilirse ızgara hücresi genişliği ([sideH] yoksa kare).
  final double? side;
  final double? sideH;

  /// Hücre köşeleri (ızgarada dış köşeler 18, iç köşeler 6).
  final BorderRadiusGeometry? radius;

  /// Izgarada gösterilmeyen görsel sayısı (son hücrede "+N").
  final int more;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // SABİT KARE (boyut/oran bilinmeden yerleşir: kaydırmada yükseklik zıplamaz); BoxFit.cover merkezden kırpar.
    final width = side ?? maxW;
    final height = sideH ?? side ?? width;
    final video = isVideoAttachment(attachment);
    // Kaynak: kutu x DPR'yi karşılayan en küçük (thumbUrl yeterliyse o, değilse ana görsel); videoda yalnız poster.
    final src = pickChatImageSource(attachment, boxW: width, boxH: height, dpr: dpr);
    final thumb = src?.path;
    final hidden = attachment['removed'] == true || (thumb == null && !video);
    final durationMs = (attachment['durationMs'] as num?)?.toInt();
    final decode = src?.decodeWidth ?? (width * dpr).ceil().clamp(160, 1600);

    Widget withOverlay(Widget w) => overlay == null ? w : Stack(fit: StackFit.expand, children: [w, overlay!]);

    Widget box(Widget child) => ClipRRect(
          borderRadius: radius ?? BorderRadius.circular(18),
          child: SizedBox(width: width, height: height, child: child),
        );

    if (hidden) {
      return Semantics(
        label: context.l10n.chatMiscImageUnavailable,
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
          ? (durationMs != null ? context.l10n.chatMiscVideoWithDuration(formatMediaDuration(durationMs)) : context.l10n.chatMiscVideo)
          : context.l10n.chatMiscPhoto,
      onTap: onTap,
      child: BuPressable(
        scale: .98,
        onTap: onTap,
        child: box(Stack(fit: StackFit.expand, children: [
          if (thumb == null)
            withOverlay(ColoredBox(color: t.sf2))
          else
            Image.network(
              chatMediaUrl(thumb),
              headers: headers,
              fit: BoxFit.cover,
              cacheWidth: decode,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              // İlk kareye kadar (bağlantı + indirme) iskelet; kare gelince renk zemin üstünde belirir.
              frameBuilder: (c, child, frame, sync) {
                if (sync) return withOverlay(child);
                // Gönderenin yerel önizlemesi (sunucu yanıtına geçişte): iskelet/flaş yok, net kare üstünde belirir.
                final ph = placeholder == null
                    ? null
                    : Image.memory(placeholder!, fit: BoxFit.cover, cacheWidth: decode, filterQuality: FilterQuality.medium, gaplessPlayback: true);
                if (frame == null) {
                  return ph == null ? ChatdSkeleton(showLabel: side == null && height >= 90) : withOverlay(ph);
                }
                return withOverlay(ColoredBox(
                  color: t.sf2,
                  child: Stack(fit: StackFit.expand, children: [
                    if (ph != null) ph,
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: BuMotion.of(c, BuMotion.medium),
                      curve: BuMotion.decelerate,
                      builder: (c, v, ch) => Opacity(opacity: v, child: ch),
                      child: child,
                    ),
                  ]),
                ));
              },
              errorBuilder: (c, e, s) => withOverlay(ColoredBox(
                color: t.sf2,
                // Videoda oynat simgesi zaten ortada: kırık görsel simgesi onunla üst üste binmesin.
                child: video ? null : Center(child: Icon(LucideIcons.imageOff, color: t.mut)),
              )),
            ),
          if (video && more == 0) ...[
            ColoredBox(color: t.scrim.withValues(alpha: .12)),
            Center(child: PlayBadge(size: side != null ? 36 : 52)),
            if (durationMs != null) PositionedDirectional(start: 8, top: 8, child: ChatdDuration(ms: durationMs)),
          ],
          if (more > 0)
            ColoredBox(
              color: t.scrim.withValues(alpha: .55),
              child: Center(
                child: Text('+$more', textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.headlineSmall!.copyWith(color: t.onMedia)),
              ),
            ),
        ])),
      ),
    );
  }
}

/// Tam ekran görsel görüntüleyici (yakınlaştır / kaydır / çift dokunuşla büyüt). Tek dokunuş üst çubuğu gizler.
class ChatImageViewer extends StatefulWidget {
  const ChatImageViewer({super.key, required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  bool _bars = true;

  @override
  Widget build(BuildContext context) {
    return ChatdMediaScaffold(
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _bars = !_bars),
            child: ChatZoomImage(url: widget.url, headers: widget.headers),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          top: 0,
          child: ChatdChrome(
            visible: _bars,
            child: ChatdTopBar(
              child: Row(children: [
                ChatdRoundButton(icon: LucideIcons.x, tooltip: context.l10n.chatMiscClose, onPressed: () => Navigator.pop(context)),
              ]),
            ),
          ),
        ),
      ]),
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
      if (mounted) {
        setState(() => _p = (_from * (1 - Curves.easeOutCubic.transform(_back.value))).clamp(0.0, _max).toDouble());
      }
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
              child: Transform.scale(
                scale: .5 + .5 * k,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: (_armed ? t.soft : t.sf2).withValues(alpha: k), shape: BoxShape.circle),
                  child: Icon(LucideIcons.reply, size: 15, color: (_armed ? t.onSoft : t.mut).withValues(alpha: k)),
                ),
              ),
            ),
          ),
        Transform.translate(offset: Offset(_p * sign, 0), child: widget.child),
      ]),
    );
  }
}

/// Tek gösterimlik fotoğraf kartı: gerçek önizleme ASLA çizilmez, yalnız durum gösterilir.
/// Alıcıda açılabilir: koyu kart + "Görüntüle" düğmesi; açılmış/gönderildi/gönderiliyor: hap.
class ViewOnceCard extends StatelessWidget {
  const ViewOnceCard({super.key, required this.mine, required this.opened, this.sending = false, this.onTap, this.meta});

  final bool mine;
  final bool opened;
  final bool sending;
  final VoidCallback? onTap;

  /// Saat/durum satırı (yalnız metin yokken; kartta sağ altta, hapta etiketin yanında).
  final Widget? meta;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    // Anlamsal etiket (ekran okuyucu): eylemi söyler.
    final semLabel = opened
        ? l.chatMiscOnceOpened
        : mine
            ? (sending ? l.chatMiscOnceSending : l.chatMiscOnceSent)
            : l.chatMiscOnceTapToOpen;
    final locked = !mine && !opened && onTap != null;

    Widget content;
    if (locked) {
      // Marka lacivertinde (her iki temada) koyu kart: medya baloncuğuyla aynı ağırlıkta durur.
      final navy = BuTokens.light.ink;
      content = Container(
        width: 272,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            OnceBadge(color: t.onMedia, dashed: true, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Icon(LucideIcons.camera, size: 14, color: t.onMedia.withValues(alpha: .85)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.chatMiscOnceTapToOpen, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: t.onMedia, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 2),
                Text(l.p08OnceSubtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: t.onMedia.withValues(alpha: .62))),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: t.pr, borderRadius: BuRadius.bPill),
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.eye, size: 16, color: t.onPr),
                const SizedBox(width: 8),
                Text(l.chatdOnceView, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(color: t.onPr, fontWeight: FontWeight.w800)),
              ]),
            ),
            const Spacer(),
            if (meta != null) meta!,
          ]),
        ]),
      );
    } else {
      final fg = mine ? t.onSoft : t.mut;
      final label = opened
          ? l.chatdOnceOpenedFull
          : mine
              ? (sending ? l.chatMiscOnceSending : l.chatMiscOnceSent)
              : l.chatdOnceLocked;
      final sentSub = mine && !opened && !sending;
      content = Row(mainAxisSize: MainAxisSize.min, children: [
        OnceBadge(color: mine ? t.pr : fg, dashed: true, size: sentSub ? 28 : 22),
        const SizedBox(width: 10),
        Flexible(
          child: sentSub
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: t.pr, fontWeight: FontWeight.w700)),
                  Text(l.p08OnceSentSub, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelSmall!.copyWith(color: fg.withValues(alpha: .8))),
                ])
              : Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ),
        if (meta != null) ...[const SizedBox(width: 8), meta!],
      ]);
    }
    final card = Semantics(
      button: onTap != null,
      label: l.chatMiscOnceSemantics(semLabel),
      excludeSemantics: true,
      child: content,
    );
    return onTap == null
        ? card
        : BuPressable(
            key: const ValueKey('viewOnceCard'),
            scale: .98,
            haptic: BuHaptic.light,
            onTap: onTap,
            child: card,
          );
  }
}

/// İçinde "1" yazan yuvarlak (tek gösterimlik simgesi); [dashed] iken kesikli çizgi.
class OnceBadge extends StatelessWidget {
  const OnceBadge({super.key, required this.color, this.dashed = false, this.size = 28});

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
          child: Text('1', style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color, fontWeight: FontWeight.w800, height: 1, fontSize: size >= 24 ? size * .5 : 11)),
        ),
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
  bool shouldRepaint(_RingPainter old) => old.color != color || old.dashed != dashed;
}
