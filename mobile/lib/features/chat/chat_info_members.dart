import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import 'chat_info_parts.dart';
import 'chatlist_widgets.dart';

bool isAdminRole(Map<String, dynamic> m) =>
    m['role'] == 'ADMIN' || m['role'] == 'OWNER';

String _memberName(BuildContext context, Map<String, dynamic> m) =>
    (m['displayName'] as String?) ?? context.l10n.chatInfoUser;

String _memberSub(Map<String, dynamic> m) =>
    (m['department'] ?? m['faculty'] ?? '').toString().trim();

/// Bilgi sayfasındaki üye önizleme satırı: 44 dp avatar, ad ("(Sen)"), bölüm, sağda "Yönetici" etiketi ya da
/// (yöneticide, yönetici olmayan üyeler için) ⋮ menüsü.
class ChatMemberRow extends StatelessWidget {
  const ChatMemberRow(
      {super.key,
      required this.member,
      required this.selfId,
      this.onRemove,
      this.onTap});

  final Map<String, dynamic> member;
  final int? selfId;
  final VoidCallback? onRemove;

  /// Satıra dokunma (profil); kendi satırında çağıran null verir.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final me = (member['userId'] as num?)?.toInt() == selfId;
    var name = _memberName(context, member);
    if (me) name = '$name (${context.l10n.chatInfoYou})';
    final sub = _memberSub(member);
    final admin = isAdminRole(member);
    return InkWell(
      onTap: me ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            ChatlistAvatar(name: _memberName(context, member), url: member['avatarUrl'] as String?, size: 44, circle: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoTitle16(context)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoBody12(context)),
              ]),
            ),
            if (admin) ...[
              const SizedBox(width: 8),
              ChatInfoTag(context.l10n.chatInfoAdmin),
            ] else if (onRemove != null) ...[
              const SizedBox(width: 4),
              PopupMenuButton<int>(
                tooltip: context.l10n.p09MemberOptions,
                icon: Icon(LucideIcons.ellipsisVertical, size: 20, color: t.mut),
                onSelected: (_) => onRemove!(),
                itemBuilder: (c) => [
                  PopupMenuItem<int>(
                    value: 1,
                    child: Row(children: [
                      Icon(LucideIcons.userMinus, size: 18, color: t.danger),
                      const SizedBox(width: 12),
                      Text(context.l10n.chatInfoRemoveFromGroup, style: chatInfoLabel14(context, color: t.danger)),
                    ]),
                  ),
                ],
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Üyeler sayfasındaki satır: 48 dp avatar, ad + "Sen"/"Yönetici" etiketleri, bölüm; sağda kalkan (yönetici)
/// ya da (yöneticide, yönetici olmayan üyeler için) "Gruptan çıkar" düğmesi.
class ChatMemberListRow extends StatelessWidget {
  const ChatMemberListRow(
      {super.key, required this.member, required this.selfId, this.onRemove, this.onTap});

  final Map<String, dynamic> member;
  final int? selfId;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final me = (member['userId'] as num?)?.toInt() == selfId;
    final name = _memberName(context, member);
    final sub = _memberSub(member);
    final admin = isAdminRole(member);
    return InkWell(
      onTap: me ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            ChatlistAvatar(name: name, url: member['avatarUrl'] as String?, size: 48, circle: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: chatInfoTitle16(context).copyWith(fontWeight: FontWeight.w400)),
                  if (me) ChatInfoTag(context.l10n.chatInfoYou, large: false),
                  if (admin) ChatInfoTag(context.l10n.chatInfoAdmin, soft: true, large: false),
                ]),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: chatInfoBody14(context)),
              ]),
            ),
            if (admin) ...[
              const SizedBox(width: 8),
              ExcludeSemantics(child: Icon(LucideIcons.shield, size: 20, color: t.mut.withValues(alpha: .55))),
            ] else if (onRemove != null) ...[
              const SizedBox(width: 8),
              _RemoveButton(onTap: onRemove!, compact: MediaQuery.textScalerOf(context).scale(1) > 1.15),
            ],
          ]),
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap, this.compact = false});

  final VoidCallback onTap;

  /// Büyük yazı ölçeğinde yalnız simge (48 dp), etiket erişilebilirlik adında kalır: ad satırı genişliği korunur.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final label = context.l10n.chatInfoRemoveFromGroup;
    void tap() {
      buHaptic(BuHaptic.selection);
      onTap();
    }

    // Görsel hap 36 dp; dokunma hedefi 48 dp.
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48, minWidth: compact ? 48 : 0, maxWidth: 160),
          child: Center(
            widthFactor: 1,
            child: BuPressable(
              scale: .97,
              child: Container(
                constraints: BoxConstraints(minHeight: compact ? 44 : 36, minWidth: compact ? 44 : 0),
                padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12, vertical: 6),
                decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bSm),
                child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(LucideIcons.userMinus, size: compact ? 20 : 16, color: t.onSoft),
                  if (!compact) const SizedBox(width: 4),
                  if (!compact) Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: chatInfoLabel14(context, color: t.onSoft).copyWith(fontWeight: FontWeight.w500))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tüm üyeler: aramalı tam sayfa (Stitch 24-4).
///
/// [onRemove]: yönetici için çıkarma (onayı çağıran sorar); true dönerse üye listeden düşer, null ise düğme yok.
/// [onAdd]: "Üye ekle" düğmesi; güncel üye listesini (ya da iptalde null) döner.
/// [onReload]: listeyi sunucudan yeniler; hata atarsa "Üye listesi alınamadı." bandı çıkar.
class ChatMembersPage extends StatefulWidget {
  const ChatMembersPage({
    super.key,
    required this.members,
    required this.selfId,
    this.onRemove,
    this.onAdd,
    this.onReload,
    this.onOpenProfile,
  });

  final List<Map<String, dynamic>> members;
  final int? selfId;
  final Future<bool> Function(Map<String, dynamic> member)? onRemove;
  final Future<List<Map<String, dynamic>>?> Function()? onAdd;
  final Future<List<Map<String, dynamic>>> Function()? onReload;
  final void Function(Map<String, dynamic> member)? onOpenProfile;

  @override
  State<ChatMembersPage> createState() => _ChatMembersPageState();
}

class _ChatMembersPageState extends State<ChatMembersPage> {
  late List<Map<String, dynamic>> _all = List.of(widget.members);
  final _ctl = TextEditingController();
  String _q = '';
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_all.isEmpty && widget.onReload != null) _reload();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await widget.onReload!();
      if (!mounted) return;
      setState(() {
        _all = List.of(list);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _add() async {
    final list = await widget.onAdd!();
    if (list == null || !mounted) return;
    setState(() => _all = List.of(list));
  }

  bool _canRemove(Map<String, dynamic> m) =>
      widget.onRemove != null && (m['userId'] as num?)?.toInt() != widget.selfId && !isAdminRole(m);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final q = chatInfoFold(_q.trim());
    final list = q.isEmpty
        ? _all
        : _all.where((m) => chatInfoFold((m['displayName'] as String?) ?? '').contains(q)).toList();
    final Widget body;
    if (_loading) {
      body = const _MembersSkeleton();
    } else if (_failed && _all.isEmpty) {
      body = _MembersError(onRetry: _reload);
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(_all.isEmpty ? context.l10n.chatInfoNoMembers : context.l10n.chatInfoNoResults, style: chatInfoBody14(context))),
      );
    } else {
      body = ChatInfoCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: t.sf2),
            ChatMemberListRow(
              member: list[i],
              selfId: widget.selfId,
              onTap: widget.onOpenProfile == null ? null : () => widget.onOpenProfile!(list[i]),
              onRemove: _canRemove(list[i])
                  ? () async {
                      final m = list[i];
                      if (await widget.onRemove!(m) && mounted) setState(() => _all.remove(m));
                    }
                  : null,
            ),
          ],
        ]),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ChatInfoBar(title: context.l10n.chatInfoMembersCount(_all.length.toString())),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, 24),
            children: [
              _SearchBox(
                controller: _ctl,
                hint: context.l10n.chatInfoSearchMember,
                onChanged: (v) => setState(() => _q = v),
              ),
              const SizedBox(height: 16),
              if (_failed && _all.isNotEmpty) ...[_MembersError(onRetry: _reload), const SizedBox(height: 16)],
              body,
            ],
          ),
        ),
        // "Üye ekle" alt çubuğa sabit (referans 24-4).
        if (widget.onAdd != null && !_loading)
          Container(
            color: t.bg,
            padding: EdgeInsets.fromLTRB(kChatInfoMargin, 8, kChatInfoMargin, MediaQuery.paddingOf(context).bottom + 12),
            child: BuButton(label: context.l10n.sohbetyAddMember, icon: LucideIcons.userPlus, onPressed: _add),
          ),
      ]),
    );
  }
}

/// Arama kutusu: beyaz, 16 köşe, hafif gölge; yazınca sağda temizle düğmesi.
class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(color: t.sf, borderRadius: BuRadius.bMd, boxShadow: BuElevation.of(context, 1)),
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(children: [
        ExcludeSemantics(child: Icon(LucideIcons.search, size: 20, color: t.mut)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            cursorColor: t.pr,
            style: tx.bodyMedium!.copyWith(color: t.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              hintText: hint,
              hintStyle: tx.bodyMedium!.copyWith(color: t.mut),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (c, _) => controller.text.isEmpty
              ? const SizedBox(width: 12)
              : IconButton(
                  tooltip: context.l10n.commonClose,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: Icon(LucideIcons.x, size: 18, color: t.mut),
                ),
        ),
      ]),
    );
  }
}

class _MembersSkeleton extends StatelessWidget {
  const _MembersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ChatInfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: BuSkeletonScope(
        child: Column(children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const BuSkeleton.circle(48),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const BuSkeleton.line(width: 140, height: 14),
                  const SizedBox(height: 8),
                  BuSkeleton.line(width: 90 + (i % 3) * 20),
                ])),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Hata bandı: "Üye listesi alınamadı." + Yeniden dene.
class _MembersError extends StatelessWidget {
  const _MembersError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final onErr = Theme.of(context).brightness == Brightness.dark ? t.danger : t.onSoft;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.soft, borderRadius: BuRadius.bMd),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.danger.withValues(alpha: .1), borderRadius: BuRadius.bSm),
          child: Icon(LucideIcons.circleAlert, size: 22, color: t.danger),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(context.l10n.p09MembersLoadFailed, style: chatInfoLabel14(context, color: onErr))),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          child: BuPressable(
            scale: .97,
            child: Material(
              color: t.ink,
              borderRadius: BuRadius.bSm,
              child: InkWell(
                borderRadius: BuRadius.bSm,
                onTap: onRetry,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.refreshCw, size: 16, color: t.bg),
                      const SizedBox(width: 4),
                      Text(context.l10n.commonRetry, style: chatInfoLabel12(context, color: t.bg)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}


/// `PUT {path}` ile multipart (`file`) yükleme; [MultipartUploader] yalnız POST yapar.
Future<dynamic> putMultipartImage(
    Session session, String path, PreparedImage image) async {
  Future<dynamic> send(bool retried) async {
    final api = session.api;
    final req = http.MultipartRequest('PUT', Uri.parse('$apiBase$path'));
    req.headers['Accept-Language'] = api.lang;
    req.headers['Accept'] = 'application/json';
    final tok = api.tokens;
    if (tok != null) req.headers['Authorization'] = 'Bearer ${tok.access}';
    req.files.add(http.MultipartFile.fromBytes('file', image.bytes,
        filename: image.fileName, contentType: MediaType.parse(image.mime)));
    http.Response res;
    try {
      res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 60)));
    } catch (_) {
      throw ApiError(0, 'NETWORK', '');
    }
    if (res.statusCode == 401 && tok != null && !retried) {
      await api.refresh();
      return send(true);
    }
    dynamic json;
    final text = utf8.decode(res.bodyBytes);
    if (text.isNotEmpty) {
      try {
        json = jsonDecode(text);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    if (json is Map && json['code'] is String) {
      throw ApiError(res.statusCode, json['code'] as String,
          (json['message'] as String?) ?? '');
    }
    throw ApiError(res.statusCode, 'HTTP_${res.statusCode}', '');
  }

  return send(false);
}
