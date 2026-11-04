import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import 'message_bubble.dart';

class MessageInfoPage extends StatefulWidget {
  const MessageInfoPage(
      {super.key,
      required this.session,
      required this.message,
      required this.peerName});
  final Session session;
  final Map<String, dynamic> message;
  final String peerName;

  @override
  State<MessageInfoPage> createState() => _MessageInfoPageState();
}

class _MessageInfoPageState extends State<MessageInfoPage> {
  Map<String, dynamic>? _data;
  Object? _error;
  bool _loadingMore = false;
  final _replies = <Map<String, dynamic>>[];
  int? _cursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more) setState(() => _loadingMore = true);
    try {
      final id = widget.message['id'];
      final response = await widget.session.api
              .get('/messages/$id/info${more ? '?before=$_cursor' : ''}')
          as Map<String, dynamic>;
      if (!mounted) return;
      final page = response['replies'] as Map? ?? const {};
      setState(() {
        _data = response;
        _error = null;
        if (!more) _replies.clear();
        _replies.addAll((page['items'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m)));
        _cursor = (page['nextCursor'] as num?)?.toInt();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted && more) setState(() => _loadingMore = false);
    }
  }

  String _time(Object? raw, {required bool happened}) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null)
      return happened
          ? context.l10n.chatMessageTimeUnknown
          : context.l10n.chatMessageWaiting;
    final local = MaterialLocalizations.of(context);
    final time = local.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true);
    return '${local.formatFullDate(date)} · $time:${date.second.toString().padLeft(2, '0')}';
  }

  Widget _bubble(Map<String, dynamic> message, {required bool mine}) =>
      MessageBubble(
        message: message,
        mine: mine,
        senderName: null,
        replyName: null,
        seen: message['status'] == 'READ',
        authHeaders: widget.session.api.tokens?.access == null
            ? const {}
            : {'Authorization': 'Bearer ${widget.session.api.tokens!.access}'},
        onMenu: () {},
        onRetry: () {},
        onOpenImage: (_) {},
        onReact: (_) {},
        preview: true,
      );

  Widget _receipt(String label, IconData icon, Object? value, bool happened) {
    final t = context.bu;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: happened ? t.soft : t.sf2,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: happened ? t.onSoft : t.mut, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(_time(value, happened: happened),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: t.mut)),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final message = _data?['message'] is Map
        ? Map<String, dynamic>.from(_data!['message'] as Map)
        : widget.message;
    final status = (_data?['status'] ?? message['status'] ?? 'SENT').toString();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
            title: l.chatMessageInfoTitle,
            onBack: () => Navigator.pop(context)),
        Expanded(
            child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _bubble(message, mine: true)),
              const SizedBox(height: 24),
              if (_data == null && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                ErrorView(error: _error!, onRetry: () => _load()),
              Container(
                decoration: BoxDecoration(
                    color: t.sf,
                    border: Border.all(color: t.bdSubtle),
                    borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  _receipt(l.chatMessageSent, BuIcons.check,
                      _data?['sentAt'] ?? message['createdAt'], true),
                  Divider(
                      height: 1, indent: 74, endIndent: 18, color: t.bdSubtle),
                  _receipt(
                      l.chatMessageDelivered,
                      BuIcons.checkCheck,
                      _data?['deliveredAt'],
                      status == 'READ' || status == 'DELIVERED'),
                  Divider(
                      height: 1, indent: 74, endIndent: 18, color: t.bdSubtle),
                  _receipt(l.chatMessageRead, BuIcons.eye, _data?['readAt'],
                      status == 'READ'),
                ]),
              ),
              const SizedBox(height: 28),
              Text(l.chatMessageReplies,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              if (_data != null && _replies.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(l.chatMessageNoReplies,
                        style: TextStyle(color: t.mut))),
              for (final reply in _replies) ...[
                Text(
                    reply['senderId'] == message['senderId']
                        ? l.chatDetailYou
                        : widget.peerName,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium!
                        .copyWith(color: t.mut)),
                const SizedBox(height: 6),
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _bubble(reply,
                        mine: reply['senderId'] == message['senderId'])),
                const SizedBox(height: 16),
              ],
              if (_cursor != null)
                TextButton(
                  onPressed: _loadingMore ? null : () => _load(more: true),
                  child: _loadingMore
                      ? const CircularProgressIndicator()
                      : Icon(BuIcons.chevronDown, color: t.ink),
                ),
            ],
          ),
        )),
      ]),
    );
  }
}
