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
import 'clubs_widgets.dart' show ClubOutlineButton;

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
const double _coverH = 180;

/// Sekme kimlikleri (içsel). Görünüm sırası (Stitch v3): Hakkında, Etkinlikler, Üyeler, Gönderiler.
/// Anketler artık Hakkında sekmesinin altında bir bölümdür (davranış korunur).
const int _tabPosts = 0, _tabEvents = 1, _tabMembers = 2, _tabAbout = 4;
const _tabOrder = [_tabAbout, _tabEvents, _tabMembers, _tabPosts];

class _ClubDetailPageState extends State<ClubDetailPage> {
  Map<String, dynamic>? _club;
  Object? _error;
  bool _busy = false;
  int _tab = _tabAbout;
  int _pollGen = 0; // çekme-yenilemede anket sekmesini yeniden yükler

  final _posts = _Paged();
  final _events = _Paged();
  final _members = _Paged();
  final _requests = _Paged();
  final _none = _Paged(); // Hakkında sekmesi sayfalı içerik taşımaz

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

  _Paged get _cur => switch (_tab) { _tabPosts => _posts, _tabEvents => _events, _tabMembers => _members, _ => _none };

  String get _curPath => switch (_tab) {
        _tabPosts => '$_base/posts',
        _tabEvents => '/events?communityId=${widget.communityId}',
        _ => '$_base/members',
      };

  void _refreshTab({bool reset = false}) {
    if (_tab == _tabAbout) return; // Hakkında: anket bölümü kendi içeriğini yükler
    _fetch(_cur, _curPath, reset: reset);
  }

  void _more() {
    if (_tab == _tabAbout) return;
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
    if (i != _tabAbout && !_locked && !_cur.loaded) _refreshTab(reset: true);
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
        await _createEvent();
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
                labels: [l10n.profileAboutShort, l10n.clubTabEvents, l10n.clubTabMembers, l10n.clubTabPosts],
                index: _tabOrder.indexOf(_tab),
                onChanged: (i) => _setTab(_tabOrder[i]),
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
    final hasPhoto = fileUrl(_club!['coverUrl']?.toString()) != null;
    return ValueListenableBuilder<bool>(
      valueListenable: _collapsed,
      builder: (context, collapsed, _) {
        final onPhoto = hasPhoto && !collapsed;
        final fg = onPhoto ? t.onMedia : t.ink;
        return SliverAppBar(
          pinned: true,
          expandedHeight: _coverH,
          backgroundColor: t.bg,
          surfaceTintColor: t.bg.withValues(alpha: 0),
          scrolledUnderElevation: 0,
          // Kapak fotoğrafı (koyu) durum çubuğunun arkasındadır: açılışta saat/simgeler açık renk, daralınca tema rengi.
          systemOverlayStyle: onPhoto
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                )
              : null,
          automaticallyImplyLeading: false,
          leadingWidth: 60,
          // Stitch v3: yalnız geri oku ve üç nokta; dairesel plaka yok. Simge ortası kenardan 36 dp.
          leading: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: ClubBarIcon(icon: LucideIcons.arrowLeft, tooltip: l10n.clubBack, onTap: () => Navigator.maybePop(context), color: fg),
          ),
          title: AnimatedSwitcher(
            duration: BuMotion.of(context, BuMotion.short),
            child: collapsed
                ? Text(name, key: const ValueKey('collapsedName'), maxLines: 1, overflow: TextOverflow.ellipsis)
                : const SizedBox.shrink(key: ValueKey('noName')),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Builder(
                builder: (anchor) => ClubBarIcon(icon: LucideIcons.ellipsisVertical, tooltip: l10n.clubOptions, onTap: () => _openMenu(anchor), color: fg),
              ),
            ),
          ],
          flexibleSpace: ClubFlatCover(url: _club!['coverUrl']?.toString(), name: name, height: _coverH),
        );
      },
    );
  }

  /// Üye rolü etiketi ("Yönetici" / "Moderatör"); sade üyede null.
  String? get _roleText {
    final l10n = context.l10n;
    return switch (_role) {
      'OWNER' || 'ADMIN' => l10n.clubRoleOwner,
      'MODERATOR' => l10n.clubRoleModerator,
      _ => null,
    };
  }

  Widget _identity(BuTokens t) {
    final c = _club!;
    final tx = Theme.of(context).textTheme;
    final desc = (c['description'] ?? '').toString().trim();
    final l10n = context.l10n;
    final cat = ClubCategories.labelFor((c['category'] ?? '').toString());
    final private = c['visibility'] == 'PRIVATE';
    final meta = [
      if (cat.isNotEmpty) cat,
      l10n.clubMemberCount('${c['memberCount'] ?? 0}'),
      private ? l10n.clubPrivate : l10n.clubPublic,
      if (_isManager && _roleText != null) _roleText!,
    ].join(' · ');
    return Padding(
      padding: BuSpace.pageH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text((c['name'] ?? '').toString(),
                maxLines: 3, overflow: TextOverflow.ellipsis, style: BuType.display.copyWith(fontSize: 28, height: 1.2, color: t.ink)),
          ),
          const SizedBox(height: 8),
          Text(meta, style: tx.bodyMedium!.copyWith(color: t.mut)),
          if (desc.isNotEmpty) ...[const SizedBox(height: 13), ClubExpandableText(desc)],
          SizedBox(height: desc.isNotEmpty ? 8 : 20),
          _cta(),
          if (_status == 'NONE' && (c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE'))
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 2, right: 2),
              child: Text(l10n.p11ApprovalNote, style: tx.bodySmall!.copyWith(color: t.mut, height: 1.4)),
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
            const SizedBox(height: 16),
            ClubRequestsBanner(
              text: l10n.kulupdetayPendingBanner('${_requests.items.length}${_requests.next != null ? '+' : ''}'),
              onTap: _openRequests,
            ),
          ],
          SizedBox(height: _isManager && _requests.items.isNotEmpty ? 20 : 24),
        ],
      ),
    );
  }

  Future<void> _createEvent() async {
    await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => EventFormPage(session: widget.session, communityId: widget.communityId)));
  }

  /// Üyelik durumuna göre ana eylem(ler): Katıl (dolu) / Kulüp sohbeti (çerçeveli) / Etkinlik oluştur (yönetici).
  Widget _cta() {
    final l10n = context.l10n;
    if (_isMember) {
      final chat = ClubOutlineButton(label: l10n.clubChat, busy: _busy, onPressed: _openChat);
      if (!_isManager) return chat;
      return Row(
        children: [
          Expanded(child: chat),
          const SizedBox(width: 12),
          Expanded(child: BuButton(label: l10n.eventListCreate, onPressed: _createEvent)),
        ],
      );
    }
    if (_isPending) {
      return Row(
        children: [
          Expanded(child: ClubOutlineButton(label: l10n.clubRequestSent)),
          const SizedBox(width: 8),
          BuButton(label: l10n.clubWithdrawConfirm, kind: BuButtonKind.text, compact: true, onPressed: _busy ? null : _withdraw),
        ],
      );
    }
    if (_status == 'BANNED') {
      return ClubOutlineButton(label: l10n.clubCannotJoin);
    }
    return BuButton(
      label: _club!['joinPolicy'] == 'APPROVAL' ? l10n.clubSendJoinRequest : l10n.clubJoin,
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
    if (_tab == _tabAbout) return _aboutContent();
    final p = _cur;
    final head = <Widget>[];
    if (_tab == _tabPosts) {
      if (_isMember) head.add(Padding(padding: _pad, child: _composer()));
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
        _tabPosts => (BuIllustration.message, l10n.clubNoPosts),
        _tabEvents => (BuIllustration.calendar, l10n.clubNoEvents),
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
                padding: EdgeInsets.only(bottom: _tab == _tabMembers ? 0 : 12),
                child: switch (_tab) {
                  _tabPosts => ClubPostCard(post: it, onMenu: _isMember && _hasPostActions(it) ? () => _openPostMenu(it) : null),
                  _tabEvents => ClubEventCard(event: it, onTap: _eventTap(it)),
                  _ => ClubMemberRow(member: it, onMenu: _isManager ? _openMembers : null),
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

  /// Hakkında: etiket-değer satırları (Kuruluş, Kategori, Katılım) + kulüp anketleri bölümü.
  List<Widget> _aboutContent() {
    final l10n = context.l10n;
    final c = _club!;
    final created = DateTime.tryParse('${c['createdAt'] ?? ''}')?.toLocal();
    final cat = ClubCategories.labelFor((c['category'] ?? '').toString());
    final approval = c['joinPolicy'] == 'APPROVAL';
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 15, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (created != null) ClubAboutRow(label: l10n.p51AboutFounded, value: '${created.year}'),
              if (cat.isNotEmpty) ClubAboutRow(label: l10n.clubMgmtCategoryLabel, value: cat),
              ClubAboutRow(label: l10n.clubMgmtJoinLabel, value: approval ? l10n.clubMgmtApprovalPolicy : l10n.clubMgmtOpenPolicy),
            ],
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: PollClubSection(
            key: ValueKey('polls-$_pollGen'),
            session: widget.session,
            communityId: widget.communityId,
            canCreate: _isManager,
            hideWhenEmpty: true),
      ),
    ];
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

/// Yükleniyor görünümü: düz kapak + ad/meta/açıklama/düğme + sekme iskeleti (dönen çember yok).
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
                    ColoredBox(color: t.sf2, child: SizedBox(height: top + _coverH, width: double.infinity)),
                    const Padding(
                      padding: BuSpace.pageH,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BuGap.h20,
                          BuSkeleton.line(width: 220, height: 28),
                          BuGap.h8,
                          BuSkeleton.line(width: 170),
                          BuGap.h16,
                          BuSkeleton.line(),
                          BuGap.h8,
                          BuSkeleton.line(width: 260),
                          BuGap.h20,
                          BuSkeleton(height: 48, radius: 16),
                          BuGap.h20,
                          BuSkeleton.line(width: 260, height: 14),
                          BuGap.h20,
                          BuSkeleton.line(),
                          BuGap.h16,
                          BuSkeleton.line(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 12,
            top: top + 4,
            child: ClubBarIcon(icon: LucideIcons.arrowLeft, tooltip: context.l10n.clubBack, onTap: () => Navigator.maybePop(context)),
          ),
        ],
      ),
    );
  }
}

/// Kulüp ayrıntısı/alt kaynağı 404 (kapatılmış `HIDDEN`, silinmiş ya da var olmayan kulüp).
bool clubIsGone(Object e) => e is ApiError && (e.status == 404 || e.code == 'COMMUNITY_NOT_FOUND');
