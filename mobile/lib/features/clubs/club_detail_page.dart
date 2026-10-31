import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/report_sheet.dart';
import '../chat/chat_detail_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_form_page.dart';
import '../polls/poll_routes.dart';
import 'club_actions.dart';
import 'club_categories.dart';
import 'club_detail_parts.dart';
import 'club_detail_sheets.dart';
import 'club_form_page.dart';
import 'club_ref_widgets.dart';
import 'club_join_flow.dart';
import 'club_members_page.dart';
import 'club_requests_page.dart';

/// Kulüp detayı: kapak, üyelik, sohbet, gönderiler / etkinlikler / üyeler / anketler.
class ClubDetailPage extends StatefulWidget {
  const ClubDetailPage({super.key, required this.session, required this.communityId, this.imageService});

  final Session session;
  final int communityId;

  /// Testlerde galeri seçicisini taklit etmek için.
  @visibleForTesting
  final ImageService? imageService;

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

/// İmleçli liste durumu (gönderi / etkinlik / üye / istek).
class _Paged {
  final items = <Map<String, dynamic>>[];
  int? next;
  bool loading = false;
  bool loaded = false;
  Object? error;
}

/// Kapak yüksekliği (durum çubuğu hariç).
const double _coverH = 208;

class _ClubDetailPageState extends State<ClubDetailPage> {
  Map<String, dynamic>? _club;
  Object? _error;
  bool _busy = false;
  int _tab = 0;
  int _pollGen = 0; // çekme-yenilemede anket sekmesini yeniden yükler

  final _posts = _Paged();
  final _events = _Paged();
  final _members = _Paged();
  final _requests = _Paged();

  final _scroll = ScrollController();
  final _text = TextEditingController();

  /// Kapak daraldı mı (başlık ve düğme renkleri buna göre değişir); yalnız eşik geçilince bildirir.
  final _collapsed = ValueNotifier<bool>(false);
  bool _sending = false;
  PreparedImage? _image;
  late final ImageService _images = widget.imageService ?? ImageService();
  // Görsel var ama yazı boş: sunucu yazıyı zorunlu tutar (400), bu yüzden göndermeden satır içi uyarılır.
  bool _needText = false;

  String get _base => '/communities/${widget.communityId}';
  String get _status => (_club?['myStatus'] ?? 'NONE').toString();
  bool get _isMember => _status == 'ACTIVE';
  bool get _isPending => _status == 'PENDING';
  String? get _role => _club?['myRole']?.toString();
  bool get _isOwner => _isMember && _role == 'OWNER';
  bool get _isManager => _isMember && isClubManagerRole(_role);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _text.dispose();
    _collapsed.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    _collapsed.value = pos.pixels > _coverH - kToolbarHeight - 12;
    if (pos.pixels > pos.maxScrollExtent - 300) _more();
  }

  Future<void> _load() async {
    _pollGen++;
    // Kategori adı etkin listeden çözülür; liste boşsa arka planda çekilip etiket tazelenir.
    if (ClubCategories.active.isEmpty) {
      ClubCategories.load(widget.session.api).then((l) {
        if (mounted && l != null) setState(() {});
      });
    }
    try {
      final r = await widget.session.api.get(_base);
      if (!mounted) return;
      setState(() {
        _club = Map<String, dynamic>.from(r as Map);
        _error = null;
      });
      // Sekmeler tembel yüklenir: yalnız açık olan çekilir, diğerleri açılınca yüklenecek.
      for (final p in [_posts, _events, _members]) {
        if (!identical(p, _cur)) {
          p.items.clear();
          p.next = null;
          p.loaded = false;
          p.error = null;
        }
      }
      if (!_locked) _refreshTab(reset: true);
      if (_isManager) {
        _fetch(_requests, _requestsPath, reset: true);
      } else {
        setState(() => _requests.items.clear());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        // Kulüp kapatıldı/silindi (404): eski veriyi göstermeye devam etme.
        if (clubIsGone(e)) _club = null;
      });
    }
  }

  String get _requestsPath => '$_base/requests?include=answers';

  _Paged get _cur => switch (_tab) { 0 => _posts, 1 => _events, _ => _members };

  String get _curPath => switch (_tab) {
        0 => '$_base/posts',
        1 => '/events?communityId=${widget.communityId}',
        _ => '$_base/members',
      };

  void _refreshTab({bool reset = false}) {
    if (_tab == 3) return; // Anketler sekmesi kendi içeriğini yükler
    _fetch(_cur, _curPath, reset: reset);
  }

  void _more() {
    if (_tab == 3) return;
    final p = _cur;
    if (p.next != null && !p.loading) _fetch(p, _curPath);
  }

  Future<void> _fetch(_Paged p, String path, {bool reset = false}) async {
    if (p.loading) return;
    setState(() {
      p.loading = true;
      if (reset) p.error = null;
    });
    try {
      final sep = path.contains('?') ? '&' : '?';
      final cursor = (!reset && p.next != null) ? '&cursor=${p.next}' : '';
      final r = await widget.session.api.get('$path${sep}size=20$cursor') as Map;
      if (!mounted) return;
      setState(() {
        if (reset) p.items.clear();
        p.items.addAll((r['items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
        p.next = (r['nextCursor'] as num?)?.toInt();
        p.loaded = true;
        p.loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          p.error = e;
          p.loading = false;
          p.loaded = true;
        });
      }
    }
  }

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  String _imageError(ImageException e) {
    final l10n = context.l10n;
    return e.code == 'TOO_LARGE'
        ? l10n.clubImageTooLarge
        : e.code == 'UNSUPPORTED_TYPE'
            ? l10n.clubImageUnsupported
            : l10n.clubImageUnreadable;
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final c = _club!;
      final st = await joinClubFlow(
        context,
        widget.session,
        communityId: widget.communityId,
        clubName: (c['name'] ?? '').toString(),
        needsApproval: c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE',
      );
      if (st != null) await _load();
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Bekleyen katılma isteğini geri çeker.
  Future<void> _withdraw() async {
    final ok = await confirmDialog(context,
        title: context.l10n.clubWithdrawTitle,
        message: context.l10n.clubWithdrawMessage,
        confirmLabel: context.l10n.clubWithdrawConfirm);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.delete('$_base/membership');
      await _load();
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Kulüpten ayrıl: onay + DELETE membership; başarıda sayfa "Katıl" durumuna döner.
  Future<void> _leave() async {
    final left = await leaveClubFlow(
      context,
      widget.session,
      communityId: widget.communityId,
      clubName: (_club?['name'] ?? '').toString(),
      isOwner: _isOwner,
    );
    if (!left || !mounted) return;
    setState(() => _busy = true);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit() async {
    final res = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ClubFormPage(session: widget.session, club: _club)),
    );
    if (res != null && mounted) await _load();
  }

  Future<void> _openRequests() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ClubRequestsPage(session: widget.session, communityId: widget.communityId)),
    );
    if (mounted) await _load();
  }

  Future<void> _openMembers() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ClubMembersPage(
              session: widget.session,
              communityId: widget.communityId,
              myRole: _role,
              clubName: (_club?['name'] ?? '').toString(),
              memberCount: (_club?['memberCount'] as num?)?.toInt())),
    );
    if (mounted) await _load();
  }

  Future<void> _changeCover() async {
    try {
      final img = await _images.pickPrepared(ImageSource.gallery);
      if (img == null || !mounted) return;
      setState(() => _busy = true);
      await MultipartUploader(widget.session).upload('$_base/cover', img);
      if (mounted) await _load();
    } on ImageException catch (e) {
      if (mounted) {
        _snack(_imageError(e));
      }
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// İki aşamalı silme: uyarı + kulüp adını yazarak onay (A28).
  Future<void> _delete() async {
    final name = (_club?['name'] ?? '').toString();
    final ok = await ClubDeleteDialog.show(context, name);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.session.api.delete(_base);
      widget.session.badges.conversationsDirty.value++;
      if (!mounted) return;
      BuToast.show(context, context.l10n.clubDeleted, kind: BuToastKind.success);
      Navigator.pop(context, 'deleted');
      return;
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openChat() async {
    setState(() => _busy = true);
    try {
      final api = widget.session.api;
      var room = await api.get('$_base/chat-room');
      room = room is Map ? Map<String, dynamic>.from(room) : <String, dynamic>{};
      if (room['joined'] != true) {
        if (room['closed'] == true) {
          if (mounted) BuToast.show(context, context.l10n.clubChatClosed, kind: BuToastKind.warning);
          return;
        }
        room = Map<String, dynamic>.from(await api.post('$_base/chat-room/join') as Map);
      }
      final cid = (room['conversationId'] as num?)?.toInt();
      if (cid == null) {
        if (mounted) BuToast.show(context, context.l10n.clubChatPreparing, kind: BuToastKind.info);
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            session: widget.session,
            conversation: {
              'id': cid,
              'type': 'GROUP',
              'title': (_club?['name'] ?? context.l10n.clubChat).toString(),
              'memberCount': room['memberCount'],
              'communityId': widget.communityId,
            },
          ),
        ),
      );
    } on ApiError catch (e) {
      if (mounted) _snack(errorText(e));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final img = await _images.pickPrepared(ImageSource.gallery);
      if (img != null && mounted) setState(() => _image = img);
    } on ImageException catch (e) {
      if (mounted) {
        _snack(_imageError(e));
      }
    } catch (_) {
      if (mounted) _snack(context.l10n.clubImagePickFailed);
    }
  }

  Future<void> _post() async {
    final text = _text.text.trim();
    if (_sending) return;
    if (text.isEmpty) {
      // Sözleşme: gönderi metni zorunlu (görsel isteğe bağlı). Yükleme/istek atılmadan satır içi hata.
      if (_image != null) setState(() => _needText = true);
      return;
    }
    final uploadFailed = context.l10n.clubImageUploadFailed;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_image != null) {
        final up = await MultipartUploader(widget.session).upload('$_base/posts/upload', _image!);
        imageUrl = up is Map ? up['url']?.toString() : null;
        if (imageUrl == null) throw ApiError(0, 'UPLOAD', uploadFailed);
      }
      await widget.session.api.post('$_base/posts', {
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      _text.clear();
      _image = null;
      _needText = false;
      if (mounted) FocusScope.of(context).unfocus();
      await _fetch(_posts, '$_base/posts', reset: true);
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deletePost(Map<String, dynamic> p) async {
    final ok = await confirmDeletePost(context);
    if (!ok || !mounted) return;
    try {
      await widget.session.api.delete('$_base/posts/${p['id']}');
      if (mounted) setState(() => _posts.items.remove(p));
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _togglePin(Map<String, dynamic> p) async {
    final pinned = p['pinned'] == true;
    try {
      final path = '$_base/posts/${p['id']}/pin';
      if (pinned) {
        await widget.session.api.delete(path);
      } else {
        await widget.session.api.put(path);
      }
      if (mounted) await _fetch(_posts, '$_base/posts', reset: true);
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _reportClub() => ReportSheet.show(context, widget.session,
      targetType: 'COMMUNITY', targetId: widget.communityId, title: context.l10n.clubReportClub);

  Future<void> _reportPost(Map<String, dynamic> p) => ReportSheet.show(context, widget.session,
      targetType: 'POST', targetId: (p['id'] as num).toInt(), title: context.l10n.clubReportPost);

  void _setTab(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    if (i != 3 && !_locked && !_cur.loaded) _refreshTab(reset: true);
  }

  Future<void> _refresh() async {
    await _load();
  }

  /// Kulüp seçenekleri (⋯) açılır menüsü; seçilen eylemi çalıştırır.
  Future<void> _openMenu(BuildContext anchor) async {
    final v = await showClubMenu(
      anchor,
      isManager: _isManager,
      isOwner: _isOwner,
      isMember: _isMember,
      pendingCount: _requests.items.length,
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'event':
        await Navigator.push<bool>(
            context, MaterialPageRoute(builder: (_) => EventFormPage(session: widget.session, communityId: widget.communityId)));
      case 'edit':
        await _edit();
      case 'requests':
        await _openRequests();
      case 'members':
        await _openMembers();
      case 'cover':
        await _changeCover();
      case 'delete':
        await _delete();
      case 'leave':
        await _leave();
      case 'report':
        await _reportClub();
    }
  }

  Future<void> _openPostMenu(Map<String, dynamic> p) async {
    final v = await showPostMenuSheet(
      context,
      canPin: _isManager,
      pinned: p['pinned'] == true,
      canDelete: p['canDelete'] == true,
      canReport: _canReportPost(p),
    );
    if (v == null || !mounted) return;
    switch (v) {
      case 'pin':
        await _togglePin(p);
      case 'delete':
        await _deletePost(p);
      case 'report':
        await _reportPost(p);
    }
  }

  bool _canReportPost(Map<String, dynamic> p) => _isMember && (p['authorId'] as num?)?.toInt() != widget.session.userId;

  bool _hasPostActions(Map<String, dynamic> p) => _isManager || p['canDelete'] == true || _canReportPost(p);

  // -------------------------------------------------------------------------------------------------------------
  // Yapı

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l10n = context.l10n;
    if (_error != null && _club == null) {
      // Kulüp kapatıldı (HIDDEN) ya da silindi: etkinlik ve sohbet odası da kapanır; yeniden denemenin anlamı yok.
      final gone = clubIsGone(_error!);
      return Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(title: Text(l10n.clubTitle)),
        body: gone
            ? ListView(
                key: const ValueKey('clubUnavailable'),
                padding: const EdgeInsets.all(20),
                children: [
                  ClubNoteCard(
                    icon: LucideIcons.circlePause,
                    title: l10n.clubUnavailable,
                    body: l10n.p11UnavailableBody,
                    badge: l10n.p11UnderReview,
                  ),
                ],
              )
            : BuErrorState(
                error: _error,
                onRetry: () {
                  setState(() => _error = null);
                  _load();
                }),
      );
    }
    if (_club == null) return const _DetailSkeleton();
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: RefreshIndicator(
        color: t.pr,
        backgroundColor: t.sf3,
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _appBar(t),
            SliverToBoxAdapter(child: _identity(t)),
            SliverPersistentHeader(
              pinned: true,
              delegate: ClubTabsDelegate(
                labels: [l10n.clubTabPosts, l10n.clubTabEvents, l10n.clubTabMembers, l10n.clubTabPolls],
                index: _tab,
                onChanged: _setTab,
                brightness: Theme.of(context).brightness,
              ),
            ),
            ..._content(t),
            SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  Widget _appBar(BuTokens t) {
    final l10n = context.l10n;
    final name = (_club!['name'] ?? '').toString();
    return ValueListenableBuilder<bool>(
      valueListenable: _collapsed,
      builder: (context, collapsed, _) => SliverAppBar(
      pinned: true,
      expandedHeight: _coverH + kClubCoverBand,
      backgroundColor: t.bg,
      surfaceTintColor: t.bg.withValues(alpha: 0),
      scrolledUnderElevation: 0,
      // Kapak (koyu görsel/ton) durum çubuğunun arkasındadır: açılışta saat/simgeler açık renk, daralınca tema rengi.
      systemOverlayStyle: collapsed || (_club!['coverUrl']?.toString() ?? '').isEmpty
          ? null
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      leading: ValueListenableBuilder<bool>(
        valueListenable: _collapsed,
        builder: (_, c, __) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: ClubRoundButton(icon: LucideIcons.arrowLeft, tooltip: l10n.clubBack, onTap: () => Navigator.maybePop(context), onCover: !c),
        ),
      ),
      title: ValueListenableBuilder<bool>(
        valueListenable: _collapsed,
        builder: (_, c, __) => AnimatedSwitcher(
          duration: BuMotion.of(context, BuMotion.short),
          child: c
              ? Text(name, key: const ValueKey('collapsedName'), maxLines: 1, overflow: TextOverflow.ellipsis)
              : const SizedBox.shrink(key: ValueKey('noName')),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: ValueListenableBuilder<bool>(
            valueListenable: _collapsed,
            builder: (_, c, __) => Builder(
              builder: (anchor) => ClubRoundButton(icon: LucideIcons.ellipsis, tooltip: l10n.clubOptions, onTap: () => _openMenu(anchor), onCover: !c),
            ),
          ),
        ),
      ],
      flexibleSpace: ClubCoverSpace(
        url: _club!['coverUrl']?.toString(),
        coverHeight: _coverH,
        seed: (_club!['id'] as num?)?.toInt() ?? widget.communityId,
        logo: _logo(t),
      ),
    ));
  }

  /// Kulüp logosu: yuvarlak; yüklenmişse görsel, yoksa kategori tonlu baş harfler. Kapakla çakışır.
  Widget _logo(BuTokens t) {
    final c = _club!;
    final tint = t.tint((c['id'] as num?)?.toInt() ?? widget.communityId);
    final tx = Theme.of(context).textTheme;
    final logo = fileUrl(c['logoUrl']?.toString());
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: logo == null ? tint.bg : t.sf,
        shape: BoxShape.circle,
        border: Border.all(color: t.bg, width: 4),
        boxShadow: BuElevation.of(context, 1),
      ),
      child: logo != null
          ? ClipOval(child: BuImage(c['logoUrl']?.toString(), width: 80, height: 80, placeholderIcon: LucideIcons.users))
          : ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(initialsOf(c['name']?.toString()), style: tx.headlineMedium!.copyWith(color: tint.fg, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  /// Kategori / üye sayısı / görünürlük çipleri (referans 28-02).
  Widget _chips(BuTokens t) {
    final c = _club!;
    final l10n = context.l10n;
    final cat = (c['category'] ?? '').toString();
    final private = c['visibility'] == 'PRIVATE';
    final catInfo = ClubCategories.find(cat);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (cat.isNotEmpty)
          _InfoChip(icon: catInfo == null ? LucideIcons.tag : ClubCategory.iconFor(catInfo.icon), text: ClubCategories.labelFor(cat)),
        _InfoChip(icon: LucideIcons.users, text: l10n.clubMemberCount('${c['memberCount'] ?? 0}')),
        _InfoChip(
          icon: private ? LucideIcons.lock : LucideIcons.globe,
          text: private ? l10n.clubPrivate : l10n.clubPublic,
          accent: private,
        ),
      ],
    );
  }

  Widget _identity(BuTokens t) {
    final c = _club!;
    final tx = Theme.of(context).textTheme;
    final desc = (c['description'] ?? '').toString().trim();
    final l10n = context.l10n;
    final roleBadge = _isMember ? clubRoleBadge(context, _role) : null;
    return Padding(
      padding: BuSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text((c['name'] ?? '').toString(),
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: tx.headlineSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w800)),
              ),
              if (roleBadge != null && _isManager) roleBadge,
            ],
          ),
          const SizedBox(height: 10),
          _chips(t),
          if (desc.isNotEmpty) ...[const SizedBox(height: 12), ClubExpandableText(desc)],
          const SizedBox(height: 12),
          _cta(),
          if (_status == 'NONE' && (c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE'))
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 2), child: ExcludeSemantics(child: Icon(LucideIcons.info, size: 15, color: t.mut))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.p11ApprovalNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4))),
                ],
              ),
            ),
          if (_isPending) ...[
            const SizedBox(height: 12),
            ClubNoteCard(icon: LucideIcons.mailCheck, title: l10n.p11PendingInfoTitle, body: l10n.p11PendingInfoBody),
          ],
          if (_status == 'BANNED') ...[
            const SizedBox(height: 12),
            ClubNoteCard(icon: LucideIcons.userX, title: l10n.p11BannedTitle, body: l10n.p11BannedBody, tone: ClubNoteTone.soft),
          ],
          if (_isManager && _requests.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClubRequestsBanner(
              text: l10n.kulupdetayPendingBanner('${_requests.items.length}${_requests.next != null ? '+' : ''}'),
              onTap: _openRequests,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Üyelik durumuna göre ana eylem(ler).
  Widget _cta() {
    final l10n = context.l10n;
    if (_isMember) {
      return Row(
        children: [
          Expanded(child: _StatusPill(label: l10n.clubIsMember, icon: LucideIcons.circleCheck)),
          const SizedBox(width: 12),
          Expanded(child: ClubBtn(label: l10n.clubChat, icon: LucideIcons.messageSquare, kind: ClubBtnKind.ink, busy: _busy, onPressed: _openChat)),
        ],
      );
    }
    if (_isPending) {
      return Row(
        children: [
          Expanded(child: _StatusPill(label: l10n.clubRequestSent, icon: LucideIcons.hourglass, muted: true)),
          const SizedBox(width: 8),
          BuButton(label: l10n.clubWithdrawConfirm, icon: LucideIcons.undo2, kind: BuButtonKind.text, compact: true, onPressed: _busy ? null : _withdraw),
        ],
      );
    }
    if (_status == 'BANNED') {
      return ClubBtn(label: l10n.clubCannotJoin, icon: LucideIcons.circleMinus, onPressed: null);
    }
    return BuButton(
      label: _club!['joinPolicy'] == 'APPROVAL' ? l10n.clubSendJoinRequest : l10n.clubJoin,
      icon: LucideIcons.userPlus,
      busy: _busy,
      onPressed: _join,
    );
  }

  /// Üye olunmadan içerik kilitli mi (özel kulüp ya da yasak)?
  bool get _locked => _club != null && (_status == 'BANNED' || (_club!['visibility'] == 'PRIVATE' && !_isMember));

  static const _pad = EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12);

  List<Widget> _content(BuTokens t) {
    final l10n = context.l10n;
    if (_locked) {
      final (icon, title, body) = _status == 'BANNED'
          ? (LucideIcons.eyeOff, l10n.p11LockBannedTitle, l10n.p11LockBannedBody)
          : _isPending
              ? (LucideIcons.lock, l10n.p11LockMembersTitle, l10n.p11LockMembersBody)
              : (LucideIcons.lock, l10n.p11LockPrivateTitle, l10n.p11LockPrivateBody);
      return [
        SliverToBoxAdapter(
          child: Padding(padding: _pad, child: ClubLockCard(icon: icon, title: title, body: body)),
        ),
      ];
    }
    if (_tab == 3) {
      return [
        SliverToBoxAdapter(
          child: PollClubSection(
              key: ValueKey('polls-$_pollGen'), session: widget.session, communityId: widget.communityId, canCreate: _isManager),
        ),
      ];
    }
    final p = _cur;
    final head = <Widget>[];
    if (_tab == 0) {
      if (_isMember) head.add(Padding(padding: _pad, child: _composer()));
    }
    if (_tab == 2 && _isManager) {
      head.add(Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: BuButton(label: l10n.clubManageMembers, icon: LucideIcons.userCog, kind: BuButtonKind.soft, compact: true, onPressed: _openMembers),
        ),
      ));
    }
    final out = <Widget>[if (head.isNotEmpty) SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: head))];
    if (p.error != null && p.items.isEmpty) {
      out.add(SliverToBoxAdapter(
          child: SizedBox(height: 300, child: BuErrorState(error: p.error, compact: true, onRetry: () => _refreshTab(reset: true)))));
      return out;
    }
    if (!p.loaded) {
      out.add(const SliverToBoxAdapter(child: BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 2, shrinkWrap: true)));
      return out;
    }
    if (p.items.isEmpty) {
      final (art, text) = switch (_tab) {
        0 => (BuIllustration.message, l10n.clubNoPosts),
        1 => (BuIllustration.calendar, l10n.clubNoEvents),
        _ => (BuIllustration.club, l10n.clubNoMembers),
      };
      out.add(SliverToBoxAdapter(child: SizedBox(height: 300, child: BuEmptyState(illustration: art, title: text, compact: true))));
      return out;
    }
    out.add(BuStaggerScope(
      key: ValueKey('tab-$_tab'),
      child: SliverPadding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: p.items.length,
          itemBuilder: (c, i) {
            final it = p.items[i];
            return BuStaggerItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: switch (_tab) {
                  0 => ClubPostCard(post: it, onMenu: _isMember && _hasPostActions(it) ? () => _openPostMenu(it) : null),
                  1 => ClubEventCard(event: it, onTap: _eventTap(it)),
                  _ => ClubMemberTile(member: it),
                },
              ),
            );
          },
        ),
      ),
    ));
    if (p.loading) {
      out.add(const SliverToBoxAdapter(child: BuSkeletonList(variant: BuSkeletonVariant.row, itemCount: 1, shrinkWrap: true)));
    } else if (p.error != null) {
      out.add(SliverToBoxAdapter(
          child: Center(child: BuButton(label: l10n.clubLoadFailedRetry, kind: BuButtonKind.text, compact: true, onPressed: _more))));
    }
    return out;
  }

  VoidCallback? _eventTap(Map<String, dynamic> e) {
    final id = (e['id'] as num?)?.toInt();
    if (id == null) return null;
    return () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailPage(session: widget.session, eventId: id)));
  }

  Widget _composer() => ListenableBuilder(
        listenable: _text,
        builder: (context, _) => ClubComposer(
          selfName: widget.session.displayName,
          controller: _text,
          image: _image,
          sending: _sending,
          needText: _needText,
          onChanged: () {
            if (_needText) setState(() => _needText = false);
          },
          onPickImage: _pickImage,
          onRemoveImage: () => setState(() => _image = null),
          onSend: _post,
        ),
      );
}

/// Yükleniyor görünümü: kapak + logo + metin + sekme + kart iskeleti (dönen çember yok).
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          Semantics(
            label: context.l10n.commonLoading,
            liveRegion: true,
            container: true,
            child: BuSkeletonScope(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(BuRadius.xl)),
                      child: BuSkeleton(height: top + _coverH, radius: 0),
                    ),
                    const Padding(
                      padding: BuSpace.pageH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 56,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [PositionedDirectional(start: 0, top: -44, child: _SkeletonLogo())],
                            ),
                          ),
                          BuSkeleton.line(width: 200, height: 24),
                          BuGap.h8,
                          BuSkeleton.line(width: 150),
                          BuGap.h16,
                          BuSkeleton.line(),
                          BuGap.h8,
                          BuSkeleton.line(width: 260),
                          BuGap.h20,
                          BuSkeleton(height: 54, radius: BuRadius.md),
                          BuGap.h20,
                          BuSkeleton(height: 52, radius: 26),
                        ],
                      ),
                    ),
                    const BuSkeletonList(variant: BuSkeletonVariant.card, itemCount: 1, shrinkWrap: true),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 10,
            top: top + 4,
            child: ClubRoundButton(icon: LucideIcons.arrowLeft, tooltip: context.l10n.clubBack, onTap: () => Navigator.maybePop(context), onCover: true),
          ),
        ],
      ),
    );
  }
}

/// Kulüp ayrıntısı/alt kaynağı 404 (kapatılmış `HIDDEN`, silinmiş ya da var olmayan kulüp).
bool clubIsGone(Object e) => e is ApiError && (e.status == 404 || e.code == 'COMMUNITY_NOT_FOUND');

/// Kimlik bölümündeki çip: simge + metin; [accent] marka tonlu (özel kulüp).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.accent = false});

  final IconData icon;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final fg = accent ? t.onSoft : t.ink;
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: accent ? t.soft : t.sf2, borderRadius: BuRadius.bPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 15, color: accent ? t.onSoft : t.mut)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: fg, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Dokunulmaz durum etiketi (52 dp): "Üyesin" / "İstek gönderildi".
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.icon, this.muted = false});

  final String label;
  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: t.sf2, borderRadius: BorderRadius.circular(BuRadius.md)),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: muted ? t.mut : t.ok),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(color: muted ? t.mut : t.ink, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yükleniyor logosu: sayfa zemini halkalı daire (kapağa gömülü görünür, düz kesilmez).
class _SkeletonLogo extends StatelessWidget {
  const _SkeletonLogo();

  @override
  Widget build(BuildContext context) => Container(
        width: 88,
        height: 88,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: context.bu.bg, shape: BoxShape.circle),
        child: const BuSkeleton.circle(80),
      );
}
