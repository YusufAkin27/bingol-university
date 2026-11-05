import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/locale_controller.dart';
import '../../../../core/session.dart';
import '../../../../widgets/bu.dart';
import '../../../profile/profil_widgets.dart';
import '../../data/forum_api.dart';
import '../../data/forum_models.dart';
import '../../data/forum_mutes.dart';
import '../widgets/forum_page_bar.dart';

/// Forum bildirim tercihleri + sessize alınanlar. Ana anahtar kapalıyken alt anahtarlar pasiftir; her anahtar
/// iyimser güncellenir, kaydetme sırayla gider (en son dokunuş kazanır), hata olursa önceki duruma döner.
/// Moderasyon bildirimi (içerik kaldırma vb.) güvenlik gereği kapatılamaz.
class ForumPrefsPage extends StatefulWidget {
  const ForumPrefsPage({super.key, required this.session});

  final Session session;

  @override
  State<ForumPrefsPage> createState() => _ForumPrefsPageState();
}

class _ForumPrefsPageState extends State<ForumPrefsPage> {
  late final ForumApi _api = ForumApi(widget.session);

  ForumNotificationPrefs? _prefs; // ekranda gösterilen (iyimser)
  ForumNotificationPrefs _server = const ForumNotificationPrefs(); // sunucunun son onayladığı
  Object? _error;
  bool _loading = true;
  int _seq = 0;
  Future<void> _chain = Future<void>.value();

  List<ForumMutedUser>? _mutes;
  Object? _mutesError;
  final Set<int> _unmuting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    unawaited(_loadMutes());
    try {
      final p = await _api.notificationPrefs();
      if (!mounted) return;
      setState(() {
        _prefs = _server = p;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMutes() async {
    setState(() => _mutesError = null);
    try {
      final m = await fetchForumMutes(widget.session, force: true);
      if (mounted) setState(() => _mutes = m);
    } catch (e) {
      if (mounted) {
        setState(() {
          _mutes = null;
          _mutesError = e;
        });
      }
    }
  }

  /// Güncel ekran durumundan türetir (kapanıştaki eski değerden değil): aynı karede art arda dokunuşlar birbirini ezmez.
  void _update(ForumNotificationPrefs Function(ForumNotificationPrefs) change) {
    final cur = _prefs;
    if (cur != null) _set(change(cur));
  }

  void _set(ForumNotificationPrefs next) {
    if (_prefs == next) return;
    buHaptic(BuHaptic.selection);
    setState(() => _prefs = next);
    final seq = ++_seq;
    _chain = _chain.then((_) async {
      try {
        final saved = await _api.saveNotificationPrefs(next);
        _server = saved;
        // Daha yeni bir dokunuş varsa onun sonucu bekleniyor: ekranı ezme.
        if (mounted && seq == _seq) setState(() => _prefs = saved);
      } catch (e) {
        if (!mounted) return;
        if (seq == _seq) setState(() => _prefs = _server);
        BuToast.show(context, errorText(e), kind: BuToastKind.error);
      }
    });
  }

  Future<void> _unmute(ForumMutedUser u) async {
    if (_unmuting.contains(u.userId)) return;
    setState(() => _unmuting.add(u.userId));
    try {
      await _api.muteUser(u.userId, false);
      if (!mounted) return;
      setState(() {
        _unmuting.remove(u.userId);
        _mutes = [...?_mutes]..removeWhere((e) => e.userId == u.userId);
      });
      BuToast.show(context, context.l10n.forumPrefsUnmuted, kind: BuToastKind.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _unmuting.remove(u.userId));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final p = _prefs;
    Widget body;
    if (_loading && p == null) {
      body = const Padding(padding: EdgeInsets.only(top: 8), child: BuSkeletonList(shrinkWrap: true, itemCount: 5));
    } else if (p == null) {
      body = SizedBox(height: 360, child: BuErrorState(error: _error, onRetry: _load));
    } else {
      final on = p.all;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ProfilCard(children: [
          ProfilToggleRow(
            key: const ValueKey('forum-pref-all'),
            icon: BuIcons.bell,
            label: l.forumPrefsAll,
            sub: l.forumPrefsAllSub,
            value: p.all,
            onChanged: (v) => _update((q) => q.copyWith(all: v)),
          ),
        ]),
        const SizedBox(height: 16),
        ProfilCard(children: [
          ProfilToggleRow(
            key: const ValueKey('forum-pref-topicComments'),
            label: l.forumPrefsTopicComments,
            value: on && p.topicComments,
            onChanged: on ? (v) => _update((q) => q.copyWith(topicComments: v)) : null,
          ),
          ProfilToggleRow(
            key: const ValueKey('forum-pref-commentReplies'),
            label: l.forumPrefsReplies,
            value: on && p.commentReplies,
            onChanged: on ? (v) => _update((q) => q.copyWith(commentReplies: v)) : null,
          ),
          ProfilToggleRow(
            key: const ValueKey('forum-pref-likes'),
            label: l.forumPrefsLikes,
            value: on && p.likes,
            onChanged: on ? (v) => _update((q) => q.copyWith(likes: v)) : null,
          ),
          ProfilToggleRow(
            key: const ValueKey('forum-pref-followedTopics'),
            label: l.forumPrefsFollowed,
            value: on && p.followedTopics,
            onChanged: on ? (v) => _update((q) => q.copyWith(followedTopics: v)) : null,
          ),
        ]),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(BuIcons.info, size: 16, color: t.mut)),
            const SizedBox(width: 8),
            Expanded(child: Text(l.forumPrefsModerationNote, key: const ValueKey('forum-pref-moderation-note'), style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut, height: 1.4))),
          ]),
        ),
        ProfilSection(l.forumPrefsMutedSection, top: 28),
        _mutedBody(t),
      ]);
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        ForumPageBar(semanticTitle: l.forumPrefsTitle),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 32),
            children: [body],
          ),
        ),
      ]),
    );
  }

  Widget _mutedBody(BuTokens t) {
    final tx = Theme.of(context).textTheme;
    final m = _mutes;
    if (_mutesError != null && m == null) {
      return ProfilCard(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Text(errorText(_mutesError!), style: tx.bodyMedium!.copyWith(color: t.mut))),
            TextButton(onPressed: _loadMutes, child: Text(context.l10n.commonRetry)),
          ]),
        ),
      ]);
    }
    if (m == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: BuSkeleton(height: 56, radius: 16));
    }
    if (m.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0),
        child: Text(context.l10n.forumPrefsMutedEmpty, key: const ValueKey('forum-muted-empty'), style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.4)),
      );
    }
    return ProfilCard(children: [
      for (final u in m)
        Container(
          key: ValueKey('forum-muted-${u.userId}'),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(children: [
            BuAvatar(name: u.displayName, url: u.avatarUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(u.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx.bodyLarge!.copyWith(color: t.ink, fontWeight: FontWeight.w400))),
            // Büyük yazıda dar ekrana sığsın: düğme kalan alanı adla paylaşır, metin tek satır kırpılır.
            Flexible(
              child: TextButton(
                key: ValueKey('forum-unmute-${u.userId}'),
                style: TextButton.styleFrom(foregroundColor: t.prText, minimumSize: const Size(48, 48)),
                onPressed: _unmuting.contains(u.userId) ? null : () => _unmute(u),
                child: Text(context.l10n.forumPrefsUnmute, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ]),
        ),
    ]);
  }
}
