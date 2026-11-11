import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/report_sheet.dart';

/// Oda (bölüm/kulüp/etkinlik) duyuru panosu API'si: `/api/conversations/{cid}/notices`.
/// Yetki sunucudadır; istemci yalnız `canManage` ipucuna göre düğmeleri gösterir.
class RoomNoticeApi {
  RoomNoticeApi(this.session, this.conversationId);

  final Session session;
  final int conversationId;

  String get _base => '/conversations/$conversationId/notices';

  /// `{items, canManage, total}`.
  Future<Map<String, dynamic>> pinned() async {
    final r = await session.api.get('$_base/pinned', force: true);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  /// `{items, nextCursor}`.
  Future<Map<String, dynamic>> list({int? cursor}) async {
    final q = cursor == null ? '' : '&cursor=$cursor';
    final r = await session.api.get('$_base?size=20$q', force: true);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  Future<void> create(String title, String body, bool pinned) =>
      session.api.post(_base, {'title': title, 'body': body, 'pinned': pinned});

  Future<void> update(int id, {String? title, String? body, bool? pinned}) =>
      session.api.patch('$_base/$id', {
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (pinned != null) 'pinned': pinned,
      });

  Future<void> remove(int id) => session.api.delete('$_base/$id');

  Future<void> seen(int id) => session.api.post('$_base/$id/seen');
}

/// Üç dilli yerel metinler (ortak l10n dosyalarına dokunmadan; dil `Localizations` koduyla seçilir).
class _S {
  _S(String code) : _c = (code == 'en' || code == 'ar') ? code : 'tr';
  final String _c;

  String _p(String tr, String en, String ar) => _c == 'en' ? en : (_c == 'ar' ? ar : tr);

  String get board => _p('Duyuru panosu', 'Notice board', 'لوحة الإعلانات');
  String get empty => _p('Henüz duyuru yok.', 'No notices yet.', 'لا توجد إعلانات بعد.');
  String get newNotice => _p('Yeni duyuru', 'New notice', 'إعلان جديد');
  String get editNotice => _p('Duyuruyu düzenle', 'Edit notice', 'تعديل الإعلان');
  String get titleHint => _p('Başlık', 'Title', 'العنوان');
  String get bodyHint => _p('Kısa metin', 'Short text', 'نص قصير');
  String get pinIt => _p('Sohbetin üstüne sabitle', 'Pin to top of chat', 'تثبيت أعلى المحادثة');
  String get publish => _p('Yayınla', 'Publish', 'نشر');
  String get save => _p('Kaydet', 'Save', 'حفظ');
  String get pin => _p('Sabitle', 'Pin', 'تثبيت');
  String get unpin => _p('Sabitlemeyi kaldır', 'Unpin', 'إلغاء التثبيت');
  String get edit => _p('Düzenle', 'Edit', 'تعديل');
  String get delete => _p('Sil', 'Delete', 'حذف');
  String get report => _p('Bildir', 'Report', 'إبلاغ');
  String get deleteTitle => _p('Duyuru silinsin mi?', 'Delete this notice?', 'حذف هذا الإعلان؟');
  String get pinned => _p('Sabit', 'Pinned', 'مثبّت');
  String seen(int n) => _p('$n kişi gördü', 'Seen by $n', 'شاهده $n');
  String more(int n) => _p('+$n duyuru daha', '+$n more', '+$n أخرى');
  String get required => _p('Başlık ve metin gerekli.', 'Title and text are required.', 'العنوان والنص مطلوبان.');
}

_S _s(BuildContext c) => _S(Localizations.localeOf(c).languageCode);

/// Sohbet odasının üstündeki sabit duyuru şeridi. Sabit duyuru yoksa ve yönetici değilse kendini gizler.
/// Şerit göründüğünde duyuru "görüldü" olarak bildirilir (sunucu kullanıcı başına bir kez sayar).
class RoomNoticeStrip extends StatefulWidget {
  const RoomNoticeStrip({super.key, required this.session, required this.conversationId});

  final Session session;
  final int conversationId;

  @override
  State<RoomNoticeStrip> createState() => _RoomNoticeStripState();
}

class _RoomNoticeStripState extends State<RoomNoticeStrip> {
  late final RoomNoticeApi _api = RoomNoticeApi(widget.session, widget.conversationId);
  final _reported = <int>{};
  List<Map<String, dynamic>> _items = [];
  bool _canManage = false;
  int _total = 0;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.pinned();
      if (!mounted) return;
      final items = ((r['items'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        _items = items;
        _canManage = r['canManage'] == true;
        _total = (r['total'] as num?)?.toInt() ?? items.length;
        if (_index >= items.length) _index = 0;
      });
      _reportSeen();
    } catch (_) {
      // Sessiz: şerit yardımcıdır, sohbeti engellemez.
    }
  }

  void _reportSeen() {
    if (_items.isEmpty) return;
    final item = _items[_index];
    final id = (item['id'] as num).toInt();
    if (item['seenByMe'] == true || !_reported.add(id)) return;
    _api.seen(id).catchError((_) {});
  }

  Future<void> _openBoard() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'room_notice_board'),
          builder: (_) => RoomNoticeBoardPage(session: widget.session, conversationId: widget.conversationId, canManage: _canManage),
        ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_canManage && _total == 0) return const SizedBox.shrink();
    final t = context.bu;
    final s = _s(context);
    final tx = Theme.of(context).textTheme;
    final item = _items.isEmpty ? null : _items[_index];
    return Material(
      color: t.soft,
      child: InkWell(
        key: const ValueKey('roomNoticeStrip'),
        onTap: _openBoard,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
          child: Row(children: [
            ExcludeSemantics(child: Icon(item == null ? BuIcons.megaphone : BuIcons.pin, size: 18, color: t.ink)),
            const SizedBox(width: 10),
            Expanded(
              child: item == null
                  ? Text(s.board, style: tx.bodyMedium?.copyWith(color: t.ink))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${item['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyMedium?.copyWith(color: t.ink)),
                      Text('${item['body']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodySmall?.copyWith(color: t.mut)),
                    ]),
            ),
            if (_items.length > 1)
              TextButton(
                onPressed: () {
                  setState(() => _index = (_index + 1) % _items.length);
                  _reportSeen();
                },
                child: Text(s.more(_items.length - 1)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Tüm duyurular listesi + (yetkiliye) yayınla / düzenle / sil / sabitle; üyeye bildir.
class RoomNoticeBoardPage extends StatefulWidget {
  const RoomNoticeBoardPage({super.key, required this.session, required this.conversationId, required this.canManage});

  final Session session;
  final int conversationId;
  final bool canManage;

  @override
  State<RoomNoticeBoardPage> createState() => _RoomNoticeBoardPageState();
}

class _RoomNoticeBoardPageState extends State<RoomNoticeBoardPage> {
  late final RoomNoticeApi _api = RoomNoticeApi(widget.session, widget.conversationId);
  List<Map<String, dynamic>> _items = [];
  int? _next;
  bool _loading = true;
  bool _loadingMore = false;
  bool _moreFailed = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _moreFailed = false;
    });
    try {
      final r = await _api.list();
      if (!mounted) return;
      setState(() {
        _items = _rows(r);
        _next = (r['nextCursor'] as num?)?.toInt();
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

  List<Map<String, dynamic>> _rows(Map<String, dynamic> r) =>
      ((r['items'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _more() async {
    if (_next == null || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final r = await _api.list(cursor: _next);
      if (!mounted) return;
      setState(() {
        _items = [..._items, ..._rows(r)];
        _next = (r['nextCursor'] as num?)?.toInt();
      });
    } catch (e) {
      // Hata sonrası otomatik yeniden deneme döngüsü olmasın: kullanıcı dokunarak yeniden dener.
      if (mounted) {
        _moreFailed = true;
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _run(Future<void> Function() job) async {
    try {
      await job();
      await _load();
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  Future<void> _editor([Map<String, dynamic>? existing]) async {
    final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'room_notice_editor'),
          builder: (_) => _NoticeEditorPage(api: _api, existing: existing),
        ));
    if (res == true && mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final s = _s(context);
    final ok = await BuConfirmSheet.show(context, title: s.deleteTitle, confirmLabel: s.delete, destructive: true, icon: BuIcons.trash2);
    if (ok && mounted) _run(() => _api.remove((n['id'] as num).toInt()));
  }

  void _menu(Map<String, dynamic> n) {
    final s = _s(context);
    final id = (n['id'] as num).toInt();
    BuSheet.show<void>(context, builder: (ctx) {
      Widget row(IconData icon, String label, VoidCallback onTap) => ListTile(
            leading: Icon(icon, color: ctx.bu.ink),
            title: Text(label),
            onTap: () {
              Navigator.pop(ctx);
              onTap();
            },
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.canManage) ...[
          row(BuIcons.pin, n['pinned'] == true ? s.unpin : s.pin,
              () => _run(() => _api.update(id, pinned: n['pinned'] != true))),
          row(BuIcons.pencil, s.edit, () => _editor(n)),
          row(BuIcons.trash2, s.delete, () => _delete(n)),
        ] else
          row(BuIcons.flag, s.report, () => ReportSheet.show(context, widget.session, targetType: 'BOARD_NOTICE', targetId: id)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final s = _s(context);
    final tx = Theme.of(context).textTheme;
    Widget body;
    if (_loading) {
      body = const Center(child: BuSpinner(size: 28));
    } else if (_error != null) {
      body = BuErrorState(error: _error, onRetry: _load);
    } else if (_items.isEmpty) {
      body = BuEmptyState(title: s.empty, icon: BuIcons.megaphone);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_next != null ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == _items.length) {
            if (_moreFailed) {
              return Center(child: TextButton(onPressed: _more, child: Text(context.l10n.commonRetry)));
            }
            // build sırasında setState çağrılmaz: sonraki kareye ertele.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _more();
            });
            return const Padding(padding: EdgeInsets.all(12), child: Center(child: BuSpinner(size: 28)));
          }
          final n = _items[i];
          final seen = (n['seenCount'] as num?)?.toInt();
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            decoration: BoxDecoration(color: t.sf, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.bd)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (n['pinned'] == true) ...[
                      ExcludeSemantics(child: Icon(BuIcons.pin, size: 14, color: t.mut)),
                      const SizedBox(width: 4),
                      Text(s.pinned, style: tx.bodySmall?.copyWith(color: t.mut)),
                      const SizedBox(width: 8),
                    ],
                    if (seen != null) Text(s.seen(seen), style: tx.bodySmall?.copyWith(color: t.mut)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${n['title']}', style: tx.titleSmall?.copyWith(color: t.ink)),
                  const SizedBox(height: 4),
                  Text('${n['body']}', style: tx.bodyMedium?.copyWith(color: t.ink)),
                  if (n['authorName'] != null) ...[
                    const SizedBox(height: 6),
                    Text('${n['authorName']}', style: tx.bodySmall?.copyWith(color: t.mut)),
                  ],
                ]),
              ),
              IconButton(
                tooltip: s.board,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(BuIcons.ellipsis),
                onPressed: () => _menu(n),
              ),
            ]),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: () => _editor(),
              icon: const Icon(BuIcons.plus),
              label: Text(s.newNotice),
            )
          : null,
      body: SafeArea(
        child: Column(children: [
          BuHeader(title: s.board, visibleTitle: true, onBack: () => Navigator.pop(context)),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

class _NoticeEditorPage extends StatefulWidget {
  const _NoticeEditorPage({required this.api, this.existing});

  final RoomNoticeApi api;
  final Map<String, dynamic>? existing;

  @override
  State<_NoticeEditorPage> createState() => _NoticeEditorPageState();
}

class _NoticeEditorPageState extends State<_NoticeEditorPage> {
  late final _title = TextEditingController(text: '${widget.existing?['title'] ?? ''}');
  late final _body = TextEditingController(text: '${widget.existing?['body'] ?? ''}');
  late bool _pin = widget.existing?['pinned'] == true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = _s(context);
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      BuToast.show(context, s.required, kind: BuToastKind.error);
      return;
    }
    setState(() => _busy = true);
    try {
      final e = widget.existing;
      if (e == null) {
        await widget.api.create(title, body, _pin);
      } else {
        await widget.api.update((e['id'] as num).toInt(), title: title, body: body, pinned: _pin);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final s = _s(context);
    final editing = widget.existing != null;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(children: [
          BuHeader(title: editing ? s.editNotice : s.newNotice, visibleTitle: true, onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              TextField(
                key: const ValueKey('noticeTitle'),
                controller: _title,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: s.titleHint),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('noticeBody'),
                controller: _body,
                maxLength: 600,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(labelText: s.bodyHint, alignLabelWithHint: true),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.pinIt),
                value: _pin,
                onChanged: (v) => setState(() => _pin = v),
              ),
              const SizedBox(height: 12),
              BuButton(label: editing ? s.save : s.publish, busy: _busy, onPressed: _busy ? null : _submit),
            ]),
          ),
        ]),
      ),
    );
  }
}
