import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import 'sohbety_sheet.dart';
import 'sohbety_widgets.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';

/// Sohbet seçici alt sayfa (İlet): sohbet listesi, arama, en çok [max] sohbet seçilir.
/// Dönüş: seçilen sohbetlerin id listesi; vazgeçilirse null.
Future<List<int>?> showForwardSheet(BuildContext context, ApiClient api,
    {int max = 5}) {
  return showSohbetySheet<List<int>>(
      context, (c) => ForwardSheet(api: api, max: max));
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

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final query = _q.text.trim().toLowerCase();
    final shown = _items
        .where((c) => query.isEmpty || titleOf(context, c).toLowerCase().contains(query))
        .toList();
    return SohbetySheetFrame(
      title: context.l10n.chatMiscForward,
      search: SohbetyField(
          hint: context.l10n.chatMiscSearchChat,
          controller: _q,
          onChanged: (_) => setState(() {})),
      note: _limit
          ? Text(context.l10n.chatMiscForwardMax(widget.max.toString()),
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: t.danger))
          : null,
      body: _list(t, shown),
      footer: SohbetyButton(
        label: _selected.isEmpty
            ? context.l10n.chatMiscSend
            : context.l10n.chatMiscSendCount(_selected.length.toString()),
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, List<int>.from(_selected)),
      ),
    );
  }

  String _typeLabel(Map<String, dynamic> c) => switch (c['type'] as String?) {
        'DIRECT' => context.l10n.sohbetyTypePerson,
        'CLUB' => context.l10n.chatInfoClub,
        'EVENT' => context.l10n.chatInfoEvent,
        _ => context.l10n.chatInfoGroup,
      };

  Widget _list(BuTokens t, List<Map<String, dynamic>> shown) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(error: _error!, onRetry: _load);
    if (shown.isEmpty) {
      return EmptyView(
          icon: LucideIcons.messageCircle, text: context.l10n.chatMiscChatNotFound);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        SohbetyCard(children: [
          for (final conv in shown)
            SohbetyRow(
              key: ValueKey('fwd-${_id(conv)}'),
              minHeight: 64,
              onTap: () => _toggle(conv),
              child: Builder(builder: (context) {
                final title = titleOf(context, conv);
                final direct = (conv['type'] as String?) == 'DIRECT';
                final peer = conv['peer'];
                final avatar = direct && peer is Map
                    ? peer['avatarUrl'] as String?
                    : conv['avatarUrl'] as String?;
                return Row(children: [
                  SohbetyAvatar(name: title, url: avatar, size: 44),
                  const SizedBox(width: 12),
                  Expanded(child: SohbetyTexts(title: title, sub: _typeLabel(conv))),
                  const SizedBox(width: 8),
                  SohbetyCheck(on: _selected.contains(_id(conv))),
                ]);
              }),
            ),
        ]),
      ],
    );
  }
}
