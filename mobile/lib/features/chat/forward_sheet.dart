import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'chat_info_parts.dart';
import 'chat_sheet_parts.dart';
import 'chatlist_widgets.dart';

/// Sohbet seçici alt sayfa (İlet, Stitch 21-6): sohbet listesi, arama, en çok [max] sohbet seçilir.
/// Dönüş: seçilen sohbetlerin id listesi; vazgeçilirse null.
Future<List<int>?> showForwardSheet(BuildContext context, ApiClient api,
    {int max = 5}) {
  return BuSheet.show<List<int>>(
    context,
    scrollable: false,
    maxHeightFactor: .94,
    padding: const EdgeInsets.symmetric(horizontal: kChatInfoMargin),
    builder: (c) => ForwardSheet(api: api, max: max),
  );
}

class ForwardSheet extends StatefulWidget {
  const ForwardSheet({super.key, required this.api, this.max = 5});

  final ApiClient api;
  final int max;

  @override
  State<ForwardSheet> createState() => _ForwardSheetState();
}

class _ForwardSheetState extends State<ForwardSheet> {
  final _items = <Map<String, dynamic>>[];
  final _selected = <int>[];
  final _q = TextEditingController();
  bool _loading = true;
  Object? _error;
  bool _limit = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.api.get('/conversations?size=50');
      final raw = res is Map ? res['items'] : null;
      final list = (raw is List ? raw : const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list.where((c) => c['blocked'] != true));
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

  static String titleOf(BuildContext context, Map<String, dynamic> c) {
    final peer = c['peer'];
    if ((c['type'] as String?) == 'DIRECT' &&
        peer is Map &&
        peer['displayName'] != null) {
      return '${peer['displayName']}';
    }
    return (c['title'] as String?) ?? context.l10n.chatMiscChat;
  }

  int _id(Map<String, dynamic> c) => (c['id'] as num).toInt();

  void _toggle(Map<String, dynamic> c) {
    final id = _id(c);
    setState(() {
      if (_selected.remove(id)) {
        _limit = false;
      } else if (_selected.length >= widget.max) {
        _limit = true;
      } else {
        _selected.add(id);
        _limit = false;
      }
    });
  }

  /// "Bireysel sohbet" ya da "Grup · 18 üye" (kulüp/etkinlik odası aynı biçimde).
  String _sub(Map<String, dynamic> c) {
    final l = context.l10n;
    final type = c['type'] as String?;
    if (type == 'DIRECT') return l.p09ForwardDirect;
    final kind = switch (type) {
      'CLUB' => l.chatInfoClub,
      'EVENT' => l.chatInfoEvent,
      _ => l.chatInfoGroup,
    };
    final n = (c['memberCount'] as num?)?.toInt() ?? 0;
    return n > 0 ? '$kind · ${l.chatInfoMemberCount(n.toString())}' : kind;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = _q.text.trim().toLowerCase();
    final shown = _items
        .where((c) => query.isEmpty || titleOf(context, c).toLowerCase().contains(query))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ChatSheetHeader(title: l.chatMiscForward),
      const SizedBox(height: 4),
      ChatSheetSearch(hint: l.chatMiscSearchChat, controller: _q, onChanged: (_) => setState(() {})),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChatSheetHint(l.chatMiscForwardMax(widget.max.toString()), warn: _limit),
      ),
      const SizedBox(height: 4),
      Expanded(child: _list(shown)),
      const SizedBox(height: 8),
      BuButton(
        label: _selected.isEmpty ? l.chatMiscSend : l.chatMiscSendCount(_selected.length.toString()),
        icon: LucideIcons.share2,
        onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, List<int>.from(_selected)),
      ),
    ]);
  }

  Widget _list(List<Map<String, dynamic>> shown) {
    if (_loading) return const BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 6);
    if (_error != null) return BuErrorState(error: _error!, onRetry: _load, compact: true);
    if (shown.isEmpty) {
      return BuEmptyState(illustration: BuIllustration.message, title: context.l10n.chatMiscChatNotFound, compact: true);
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final conv = shown[i];
        final title = titleOf(context, conv);
        final direct = (conv['type'] as String?) == 'DIRECT';
        final peer = conv['peer'];
        final avatar = direct && peer is Map ? peer['avatarUrl'] as String? : conv['avatarUrl'] as String?;
        final on = _selected.contains(_id(conv));
        return Semantics(
          button: true,
          selected: on,
          child: InkWell(
            key: ValueKey('fwd-${_id(conv)}'),
            onTap: () => _toggle(conv),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Row(children: [
                  ChatlistAvatar(name: title, url: avatar, group: !direct, circle: direct, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context)),
                      Text(_sub(conv), maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoBody12(context)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  ChatSheetCheck(on: on),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
