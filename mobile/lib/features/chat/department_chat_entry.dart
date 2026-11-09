import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'all_departments_page.dart';
import 'chat_detail_page.dart';

/// Bölüm kanalları uçları (v2: her öğrenci istediği bölüme katılıp çıkar). `{key}` katalog bölüm kimliğidir.
/// * `GET /chat/departments/mine` -> `{items:[{key,name,nameEn,nameAr,faculty,own,conversation}], own:{...}|null}`
/// * `GET /chat/departments?q=&page=&size=` -> `{items:[{key,name,...,own,joined,closed,memberCount,conversationId}], total, ownKey}`
/// * `POST /chat/departments/{key}/join` ve `POST /chat/departments/{key}/leave` (idempotent).
class DepartmentChannelsApi {
  DepartmentChannelsApi(this.session);

  final Session session;

  Future<Map<String, dynamic>> mine() async {
    final r = await session.api.get('/chat/departments/mine', force: true);
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  /// Tüm bölümler: 200'lük sayfalar, en çok 6 sayfa (katalog ~600 bölüm).
  Future<List<Map<String, dynamic>>> all() async {
    final out = <Map<String, dynamic>>[];
    for (var page = 0; page < 6; page++) {
      final r = await session.api.get('/chat/departments?page=$page&size=200', force: true);
      if (r is! Map) break;
      final items = r['items'];
      if (items is! List || items.isEmpty) break;
      for (final e in items) {
        if (e is Map) out.add(Map<String, dynamic>.from(e));
      }
      final total = (r['total'] as num?)?.toInt() ?? out.length;
      if (out.length >= total) break;
    }
    return out;
  }

  Future<Map<String, dynamic>> join(String key) async {
    final r = await session.api.post('/chat/departments/${Uri.encodeComponent(key)}/join');
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  Future<void> leave(String key) async {
    await session.api.post('/chat/departments/${Uri.encodeComponent(key)}/leave');
  }
}

/// Kanal alanının dile göre bölüm adı (sunucu `name`/`nameEn`/`nameAr` döner; eksikse Türkçe).
String deptChannelName(BuildContext context, Map<String, dynamic> c) {
  final lang = Localizations.localeOf(context).languageCode;
  final v = switch (lang) { 'en' => c['nameEn'], 'ar' => c['nameAr'], _ => c['name'] };
  final s = (v as String?)?.trim();
  return s != null && s.isNotEmpty ? s : ((c['name'] as String?) ?? '');
}

/// Fakülte adı (aynı kural).
String deptChannelFaculty(BuildContext context, Map<String, dynamic> c) {
  final lang = Localizations.localeOf(context).languageCode;
  final v = switch (lang) { 'en' => c['facultyEn'], 'ar' => c['facultyAr'], _ => c['faculty'] };
  final s = (v as String?)?.trim();
  return s != null && s.isNotEmpty ? s : ((c['faculty'] as String?) ?? '');
}

/// Kanal sohbetini açar (`conversation` = sohbet listesiyle aynı biçim).
Future<void> openDepartmentChannel(BuildContext context, Session session, Map<String, dynamic> conversation,
    {String? title}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      settings: const RouteSettings(name: 'chat_detail'),
      builder: (_) => ChatDetailPage(
        session: session,
        conversation: {...conversation, 'type': 'DEPARTMENT', if (title != null && title.isNotEmpty) 'title': title},
      ),
    ),
  );
}

/// Sohbet listesinin üstündeki "Bölüm kanallarım" alanı: katıldığın kanallar yatay kaydırmalı kartlar (ad, okunmamış
/// rozeti, son mesaj önizlemesi); hiç kanal yoksa sade öneri kartı (kendi bölümün öne çıkar) ve "Tüm bölümler"
/// bağlantısı. Yükleme/hata sessizdir (sohbet listesini etkilemez); "Tüm bölümler" ekranı kendi durumlarını gösterir.
class DepartmentChannelsStrip extends StatefulWidget {
  const DepartmentChannelsStrip({super.key, required this.session, this.onChanged});

  final Session session;

  /// Katılma/ayrılma sonrası sohbet listesi yenilensin.
  final VoidCallback? onChanged;

  @override
  State<DepartmentChannelsStrip> createState() => DepartmentChannelsStripState();
}

class DepartmentChannelsStripState extends State<DepartmentChannelsStrip> {
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic>? _own;
  bool _loaded = false;
  bool _busy = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final my = ++_seq;
    try {
      final r = await DepartmentChannelsApi(widget.session).mine();
      if (!mounted || my != _seq) return;
      final raw = r['items'];
      final own = r['own'];
      setState(() {
        _items = raw is List
            ? [for (final e in raw) if (e is Map) Map<String, dynamic>.from(e)]
            : const [];
        _own = own is Map ? Map<String, dynamic>.from(own) : null;
        _loaded = true;
      });
    } catch (_) {
      // Bilerek yutulur: en iyi çaba. Daha önce yüklenmiş alan korunur.
    }
  }

  Future<void> _openAll() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'department_channels'),
        builder: (_) => AllDepartmentsPage(session: widget.session),
      ),
    );
    if (!mounted) return;
    refresh();
    widget.onChanged?.call();
  }

  Future<void> _openChannel(Map<String, dynamic> c) async {
    final conv = c['conversation'];
    if (conv is! Map) return;
    await openDepartmentChannel(context, widget.session, Map<String, dynamic>.from(conv),
        title: deptChannelName(context, c));
    if (!mounted) return;
    refresh();
    widget.onChanged?.call();
  }

  Future<void> _joinOwn() async {
    final own = _own;
    if (own == null || _busy) return;
    setState(() => _busy = true);
    try {
      final r = await DepartmentChannelsApi(widget.session).join(own['key'] as String);
      if (!mounted) return;
      setState(() => _busy = false);
      await refresh();
      widget.onChanged?.call();
      final cid = (r['conversationId'] as num?)?.toInt();
      if (cid == null || !mounted) return;
      await openDepartmentChannel(
        context,
        widget.session,
        {'id': cid, 'memberCount': r['memberCount']},
        title: deptChannelName(context, own),
      );
      if (!mounted) return;
      refresh();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final l = context.l10n;
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final own = _own;
    final ownOpen = own != null && own['closed'] != true && own['joined'] != true;
    return Column(
      key: const ValueKey('department-channels'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 8, 0),
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(l.deptChanMine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
              ),
            ),
            TextButton(
              key: const ValueKey('department-channels-all'),
              style: TextButton.styleFrom(
                minimumSize: const Size(BuSize.touch, BuSize.touch),
                foregroundColor: t.ink,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: _openAll,
              child: Text(l.deptChanAll,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w400)),
            ),
          ]),
        ),
        if (_items.isNotEmpty)
          _Cards(items: _items, onOpen: _openChannel)
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _SuggestCard(
              own: ownOpen ? own : null,
              busy: _busy,
              onJoin: _joinOwn,
              onBrowse: _openAll,
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.bd))),
          child: const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

/// Yatay kaydırmalı kanal kartları. Yükseklik yazı ölçeğiyle (en çok 1.3) büyür; taşma olmaz.
class _Cards extends StatelessWidget {
  const _Cards({required this.items, required this.onOpen});

  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: 136 * scale,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _ChannelCard(channel: items[i], onTap: () => onOpen(items[i])),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.onTap});

  final Map<String, dynamic> channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final name = deptChannelName(context, channel);
    final conv = channel['conversation'];
    final unread = conv is Map ? (conv['unreadCount'] as num?)?.toInt() ?? 0 : 0;
    final muted = conv is Map && (conv['muted'] == true || conv['mutedForever'] == true);
    final last = conv is Map ? conv['lastMessage'] : null;
    final text = last is Map && last['removed'] != true && last['deleted'] != true
        ? ((last['text'] as String?)?.trim() ?? '')
        : '';
    final preview = text.isNotEmpty ? text : l.deptChanNoMessages;
    return Semantics(
      button: true,
      label: unread > 0 ? '$name, $unread' : name,
      excludeSemantics: true,
      onTap: onTap,
      child: BuPressable(
        scale: .98,
        child: SizedBox(
          width: 184,
          child: Material(
            color: t.sf,
            shape: RoundedRectangleBorder(borderRadius: BuRadius.bMd, side: BorderSide(color: t.bd)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                buHaptic(BuHaptic.selection);
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                        child: Icon(BuIcons.graduationCap, size: 16, color: t.onSoft),
                      ),
                      const Spacer(),
                      BuCountBadge(unread, muted: muted),
                    ]),
                    const SizedBox(height: 8),
                    Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodyMedium!.copyWith(color: t.ink, fontWeight: FontWeight.w400, height: 1.2)),
                    const Spacer(),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx.bodySmall!.copyWith(color: unread > 0 && !muted ? t.ink : t.mut)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiç kanal yokken öneri: kendi bölümün açıksa "Katıl" ile tek dokunuş, değilse "Bölümlere göz at".
class _SuggestCard extends StatelessWidget {
  const _SuggestCard({required this.own, required this.busy, required this.onJoin, required this.onBrowse});

  final Map<String, dynamic>? own;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final tx = Theme.of(context).textTheme;
    final o = own;
    final title = o != null ? l.deptChanSuggestTitle : l.deptChanBrowseTitle;
    final body = o != null ? l.deptChanSuggestBody(deptChannelName(context, o)) : l.deptChanBrowseBody;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        key: const ValueKey('department-channels-suggest'),
        decoration: BoxDecoration(
          color: t.sf,
          borderRadius: BuRadius.bMd,
          border: Border.all(color: t.bd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: t.soft, shape: BoxShape.circle),
                  child: Icon(BuIcons.graduationCap, size: 20, color: t.onSoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 2),
                    Text(body, style: tx.bodySmall!.copyWith(color: t.mut)),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (o != null)
                    BuButton(
                      key: const ValueKey('department-channels-join-own'),
                      label: l.deptChanJoin,
                      compact: true,
                      busy: busy,
                      onPressed: onJoin,
                    ),
                  BuButton(
                    key: const ValueKey('department-channels-browse'),
                    label: o != null ? l.deptChanAll : l.deptChanBrowse,
                    kind: o != null ? BuButtonKind.text : BuButtonKind.primary,
                    compact: true,
                    onPressed: onBrowse,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
