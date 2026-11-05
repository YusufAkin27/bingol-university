import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/analytics.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../chat/chat_info_parts.dart';
import '../chat/chat_sheet_parts.dart';
import '../chat/chatlist_widgets.dart';
import 'share_api.dart';
import 'share_card.dart';
import 'share_models.dart';

/// Sistem paylaşım sayfasını açan işlev (testlerde değiştirilir).
typedef ExternalShareFn = Future<void> Function(ShareParams params);

/// Test kancası: sistem paylaşım sayfası çağrısı. Varsayılan `share_plus`.
@visibleForTesting
ExternalShareFn? debugExternalShare;

Future<void> _externalShare(ShareParams p) => (debugExternalShare ?? (x) => SharePlus.instance.share(x))(p);

/// Paylaşım alt sayfası (Instagram/WhatsApp tarzı): içerik önizleme kartı, "Kişiye gönder" şeridi (son sohbetler +
/// arama, çoklu seçim, isteğe bağlı kısa not), "Bağlantıyı kopyala" ve "Diğer uygulamalar" (sistem paylaşım sayfası).
/// Gizli hesap gönderisi ([ShareContent.restricted]) yalnız kişiyle mesajla paylaşılır.
Future<void> showShareSheet(BuildContext context, Session session, ShareContent content) {
  Analytics.instance.action('share', target: 'open_${content.type.apiName.toLowerCase()}');
  return BuSheet.show<void>(
    context,
    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
    builder: (_) => ShareSheet(session: session, content: content),
  );
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.session, required this.content});

  final Session session;
  final ShareContent content;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  static const _stripMax = 20;
  static const _searchDebounce = Duration(milliseconds: 300);

  final _chats = <ShareRecipient>[];

  /// Birebir sohbeti olan kişilerin kimliği -> o sohbetin alıcısı (arama sonucunda yinelenmesin).
  final _directByUser = <int, ShareRecipient>{};
  final _selected = <String, ShareRecipient>{}; // eklenme sırası korunur
  final _q = TextEditingController();
  final _note = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  bool _loading = true;
  Object? _error;
  bool _searching = false;
  List<ShareRecipient> _people = const [];
  bool _sending = false;
  bool _limit = false;

  /// Gizli hesap gönderisi mi? true: yalnız mesajla; null: henüz doğrulanıyor (bağlantı eylemleri bekler).
  bool? _restricted;

  ShareContent get c => widget.content;

  @override
  void initState() {
    super.initState();
    _restricted = _initialRestriction();
    _load();
    if (_restricted == null) _checkAuthor();
  }

  /// Gizlilik gönderide biliniyorsa onu al; gönderi/Reels'te bilinmiyorsa (null) yazardan doğrula; diğer türler serbest.
  bool? _initialRestriction() {
    if (c.restricted) return true;
    final author = c.authorId;
    final isPost = c.type == ShareType.post || c.type == ShareType.reel;
    if (isPost && author != null && author != widget.session.userId) return null;
    return false;
  }

  Future<void> _checkAuthor() async {
    bool priv;
    try {
      final r = await widget.session.api.get('/users/${c.authorId}');
      priv = r is Map && r['isPrivate'] == true;
    } catch (_) {
      priv = true; // doğrulanamadı: gizlilik için kapalı tarafta kal
    }
    if (mounted) setState(() => _restricted = priv);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.session.api.get('/conversations?size=50');
      final raw = res is Map ? res['items'] : null;
      final list = (raw is List ? raw : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e));
      if (!mounted) return;
      final out = <ShareRecipient>[];
      final direct = <int, ShareRecipient>{};
      for (final conv in list) {
        // Engelli ve yönetici tarafından kapatılmış sohbetlere gönderilemez (İlet ile aynı kural).
        if (conv['blocked'] == true || conv['closed'] == true) continue;
        final id = (conv['id'] as num?)?.toInt();
        if (id == null) continue;
        final isDirect = (conv['type'] as String?) == 'DIRECT';
        final peer = conv['peer'];
        final r = ShareRecipient.conversation(
          conversationId: id,
          label: _titleOf(context, conv),
          avatarUrl: (isDirect && peer is Map ? peer['avatarUrl'] : conv['avatarUrl']) as String?,
          group: !isDirect,
        );
        out.add(r);
        final pid = peer is Map ? (peer['id'] as num?)?.toInt() : null;
        if (isDirect && pid != null) direct[pid] = r;
      }
      setState(() {
        _chats
          ..clear()
          ..addAll(out);
        _directByUser
          ..clear()
          ..addAll(direct);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      _seq++;
      setState(() {
        _people = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(_searchDebounce, () => _searchPeople(q));
  }

  Future<void> _searchPeople(String q) async {
    final my = ++_seq;
    try {
      final res = await widget.session.api.get('/users/search?q=${Uri.encodeQueryComponent(q)}&size=10');
      if (!mounted || my != _seq) return;
      final raw = res is Map ? res['items'] : null;
      final out = <ShareRecipient>[];
      for (final u in (raw is List ? raw : const []).whereType<Map>()) {
        final id = (u['id'] as num?)?.toInt();
        if (id == null || id == widget.session.userId) continue;
        out.add(_directByUser[id] ??
            ShareRecipient.user(userId: id, label: '${u['displayName'] ?? ''}', avatarUrl: u['avatarUrl'] as String?));
      }
      setState(() {
        _people = out;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || my != _seq) return;
      setState(() {
        _people = const [];
        _searching = false;
      });
    }
  }

  void _toggle(ShareRecipient r) {
    buHaptic(BuHaptic.selection);
    setState(() {
      if (_selected.remove(r.key) != null) {
        _limit = false;
      } else if (_selected.length >= kShareMaxRecipients) {
        _limit = true;
      } else {
        _selected[r.key] = r;
        _limit = false;
      }
    });
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    final l = context.l10n;
    setState(() => _sending = true);
    final sum = await sendShare(widget.session.api,
        to: _selected.values.toList(), target: c.target, note: _note.text);
    if (!mounted) return;
    Analytics.instance.action('share', target: 'message');
    if (sum.allFailed) {
      setState(() => _sending = false);
      BuToast.show(context, l.shareFailedAll, kind: BuToastKind.error);
      return;
    }
    final String msg;
    var kind = BuToastKind.success;
    if (sum.failed > 0) {
      msg = l.shareFailedSome(sum.failed.toString());
      kind = BuToastKind.warning;
    } else if (sum.queued > 0 && sum.sent == 0) {
      msg = l.shareQueued;
      kind = BuToastKind.info;
    } else {
      msg = sum.sent + sum.queued > 1 ? l.shareSentMany((sum.sent + sum.queued).toString()) : l.shareSentOne;
    }
    // Bildirim uygulama genelindeki ScaffoldMessenger'dadır: sayfa kapanınca da görünür.
    BuToast.show(context, msg, kind: kind);
    Navigator.of(context).pop();
  }

  Future<void> _copy() async {
    final l = context.l10n;
    await Clipboard.setData(ClipboardData(text: c.url));
    Analytics.instance.action('share', target: 'copy_link');
    if (!mounted) return;
    BuToast.show(context, l.shareLinkCopied, kind: BuToastKind.success);
    Navigator.of(context).pop();
  }

  Future<void> _external(BuildContext btnContext) async {
    final l = context.l10n;
    final box = btnContext.findRenderObject();
    final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    try {
      await _externalShare(ShareParams(
        text: c.externalText(),
        subject: (c.title ?? '').trim().isEmpty ? null : c.title!.trim(),
        sharePositionOrigin: origin,
      ));
      Analytics.instance.action('share', target: 'external');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) BuToast.show(context, l.shareExternalFailed, kind: BuToastKind.error);
    }
  }

  // ---------------------------------------------------------------- görünüm

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final query = _q.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChatSheetHeader(title: l.shareTitle),
        const SizedBox(height: 4),
        SharePreviewTile(content: c),
        const SizedBox(height: 16),
        ChatSheetSearch(hint: l.shareSearchHint, controller: _q, onChanged: (v) {
          setState(() {});
          _onQuery(v);
        }),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.medium),
          curve: BuMotion.standard,
          alignment: Alignment.topCenter,
          child: _picker(query),
        ),
        AnimatedSize(
          duration: BuMotion.of(context, BuMotion.medium),
          curve: BuMotion.standard,
          alignment: Alignment.topCenter,
          child: _selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _noteField(t, l.shareNoteHint),
                ),
        ),
        if (_limit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ChatSheetHint(l.chatMiscForwardMax(kShareMaxRecipients.toString()), warn: true),
          ),
        const SizedBox(height: 12),
        BuButton(
          key: const ValueKey('share-send'),
          label: _selected.isEmpty ? l.chatMiscSend : l.chatMiscSendCount(_selected.length.toString()),
          icon: BuIcons.send,
          busy: _sending,
          onPressed: _selected.isEmpty || _sending ? null : _send,
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: t.bd),
        const SizedBox(height: 8),
        if (_restricted == true)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ChatSheetHint(l.sharePrivateHint),
          )
        else if (_restricted == null)
          const SizedBox(height: 88) // gizlilik doğrulanırken eylemler yer tutar (düzen zıplamaz)
        else
          Row(children: [
            Expanded(
              child: ShareActionTile(
                key: const ValueKey('share-copy'),
                icon: BuIcons.copy,
                label: l.shareCopyLink,
                onTap: _copy,
              ),
            ),
            Expanded(
              child: Builder(
                builder: (bc) => ShareActionTile(
                  key: const ValueKey('share-external'),
                  icon: BuIcons.share2,
                  label: l.shareMoreApps,
                  onTap: () => _external(bc),
                ),
              ),
            ),
          ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _noteField(BuTokens t, String hint) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd),
      child: TextField(
        key: const ValueKey('share-note'),
        controller: _note,
        maxLines: 2,
        minLines: 1,
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(kShareNoteMax)],
        cursorColor: t.pr,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.ink),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: hint,
          hintStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.mut),
        ),
      ),
    );
  }

  Widget _picker(String query) {
    final l = context.l10n;
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1),
      );
    }
    if (_error != null) {
      return SizedBox(height: 120, child: BuErrorState(error: _error!, onRetry: _load, compact: true));
    }
    if (query.isEmpty) {
      if (_chats.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ChatSheetHint(l.shareNoChats),
        );
      }
      final shown = _chats.take(_stripMax).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          header: true,
          child: Text(l.shareRecent,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(color: context.bu.mut, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            key: const ValueKey('share-strip'),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) => ShareStripItem(
              key: ValueKey('share-pick-${shown[i].key}'),
              recipient: shown[i],
              selected: _selected.containsKey(shown[i].key),
              onTap: () => _toggle(shown[i]),
            ),
          ),
        ),
      ]);
    }
    // Arama: eşleşen sohbetler + kişiler (sohbeti olmayanlar dahil).
    final fq = chatInfoFold(query);
    final rows = <ShareRecipient>[
      ..._chats.where((r) => chatInfoFold(r.label).contains(fq)),
      ..._people.where((p) => !_chats.contains(p)),
    ];
    if (rows.isEmpty) {
      if (_searching) {
        return const SizedBox(height: 96, child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ChatSheetHint(l.shareNoChats),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 264),
      child: ListView.builder(
        key: const ValueKey('share-results'),
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemBuilder: (_, i) => SharePickRow(
          key: ValueKey('share-pick-${rows[i].key}'),
          recipient: rows[i],
          selected: _selected.containsKey(rows[i].key),
          onTap: () => _toggle(rows[i]),
        ),
      ),
    );
  }
}

/// Sohbet adı: birebirde karşı kişinin adı, diğerlerinde sohbet başlığı (İlet sayfasıyla aynı kural).
String _titleOf(BuildContext context, Map<String, dynamic> c) {
  final peer = c['peer'];
  if ((c['type'] as String?) == 'DIRECT' && peer is Map && peer['displayName'] != null) {
    return '${peer['displayName']}';
  }
  return (c['title'] as String?) ?? context.l10n.chatMiscChat;
}

/// Üstteki içerik önizleme kartı: küçük resim + tür etiketi + başlık + kaynak.
class SharePreviewTile extends StatelessWidget {
  const SharePreviewTile({super.key, required this.content});

  final ShareContent content;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final c = content;
    final label = shareKindLabel(context, c.type, announcement: c.isAnnouncement);
    final icon = shareKindIcon(c.type, announcement: c.isAnnouncement);
    final tint = shareKindTint(t, c.type, announcement: c.isAnnouncement);
    final title = (c.title ?? '').trim();
    final source = (c.source ?? '').trim();
    const size = 64.0;
    final thumb = ClipRRect(
      borderRadius: BuRadius.bSm,
      child: SizedBox(
        width: size,
        height: size,
        child: c.imageUrl == null
            ? ColoredBox(color: tint.bg, child: Center(child: Icon(icon, size: 26, color: tint.fg)))
            : Stack(fit: StackFit.expand, children: [
                BuImage(c.imageUrl,
                    width: size,
                    height: size,
                    headers: shareImageHeaders(c.imageUrl, c.imageHeaders),
                    maxDecodeWidth: 240,
                    placeholderIcon: icon),
                if (c.showPlay)
                  Center(child: Icon(BuIcons.playFilled, size: 22, color: t.onMedia)),
              ]),
      ),
    );
    return Container(
      key: const ValueKey('share-preview'),
      padding: const EdgeInsets.all(10),
      // 1 dp çizgi: koyu temada sf2 ile sayfa yüzeyi birbirine yakın, kart yine de seçilsin.
      decoration: BoxDecoration(color: t.sf2, borderRadius: BuRadius.bMd, border: Border.all(color: t.bd)),
      child: Row(children: [
        ExcludeSemantics(child: thumb),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14, color: t.mut),
              const SizedBox(width: 6),
              Flexible(
                child: Text(trUpper(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.labelSmall!.copyWith(color: t.mut, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w600, height: 1.3)),
            ],
            if (source.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall!.copyWith(color: t.mut)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Yatay şeritteki kişi/sohbet: 56 dp avatar, seçiliyken sağ altta onay işareti, altında tek satır ad.
class ShareStripItem extends StatelessWidget {
  const ShareStripItem({super.key, required this.recipient, required this.selected, required this.onTap});

  final ShareRecipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final r = recipient;
    return Semantics(
      button: true,
      selected: selected,
      label: r.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 72,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: BuMotion.of(context, BuMotion.short),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? t.pr : Colors.transparent, width: 2),
                ),
                child: ChatlistAvatar(name: r.label, url: r.avatarUrl, group: r.group, size: 52, circle: true),
              ),
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: AnimatedScale(
                  duration: BuMotion.of(context, BuMotion.short),
                  scale: selected ? 1 : 0,
                  child: const ChatSheetCheck(on: true),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(r.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium!
                    .copyWith(color: selected ? t.ink : t.mut, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

/// Arama sonucu satırı: avatar + ad + seçim dairesi (48 dp+ dokunma alanı).
class SharePickRow extends StatelessWidget {
  const SharePickRow({super.key, required this.recipient, required this.selected, required this.onTap});

  final ShareRecipient recipient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = recipient;
    return Semantics(
      button: true,
      selected: selected,
      label: r.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              ChatlistAvatar(name: r.label, url: r.avatarUrl, group: r.group, size: 44, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context)),
              ),
              const SizedBox(width: 8),
              ChatSheetCheck(on: selected),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Alt eylem (Bağlantıyı kopyala / Diğer uygulamalar): yuvarlak simge + etiket.
class ShareActionTile extends StatelessWidget {
  const ShareActionTile({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BuPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: t.ink),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}
