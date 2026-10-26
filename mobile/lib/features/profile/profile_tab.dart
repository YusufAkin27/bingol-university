import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'edit_profile_page.dart';
import 'my_clubs_page.dart';
import 'my_events_page.dart';
import 'saved_news_page.dart';
import 'settings_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.session, required this.themeController});

  final Session session;
  final ThemeController themeController;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late Future<Map<String, dynamic>> _future = _fetch();
  // İstatistikler: null = yüklenmedi / alınamadı.
  String? _clubs, _events, _saved;

  Future<Map<String, dynamic>> _fetch() async {
    final p = await widget.session.api.get('/users/me') as Map<String, dynamic>;
    _loadStats();
    return p;
  }

  Future<String?> _count(String path) async {
    try {
      final r = await widget.session.api.get('$path?size=50') as Map<String, dynamic>;
      final n = (r['items'] as List? ?? const []).length;
      return r['nextCursor'] != null ? '$n+' : '$n';
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadStats() async {
    final r = await Future.wait([_count('/me/communities'), _count('/me/events'), _count('/bookmarks')]);
    if (!mounted) return;
    setState(() {
      _clubs = r[0];
      _events = r[1];
      _saved = r[2];
    });
  }

  void _reload() => setState(() => _future = _fetch());

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadStats();
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(session: widget.session, profile: p)),
    );
    if (changed == true) {
      _reload();
      widget.session.refreshName();
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Bu cihazdaki oturumunuz kapatılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Çıkış yap')),
        ],
      ),
    );
    if (ok == true) widget.session.signOut();
  }

  void _openSettings() =>
      _go(SettingsPage(session: widget.session, themeController: widget.themeController));

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: 'Profil',
            actions: [BuIconButton(icon: LucideIcons.settings, tooltip: 'Ayarlar', onTap: _openSettings)],
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LoadingView();
                if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
                final p = snap.data!;
                return RefreshIndicator(
                  color: t.pr,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, kNavInset + 24),
                    children: [
                      _HeaderCard(profile: p),
                      const SizedBox(height: 12),
                      BuCard(
                        padding: EdgeInsets.zero,
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              _Stat(value: _clubs, label: 'Kulüp'),
                              VerticalDivider(width: 1, color: t.bd),
                              _Stat(value: _events, label: 'Etkinlik'),
                              VerticalDivider(width: 1, color: t.bd),
                              _Stat(value: _saved, label: 'Kayıtlı haber'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BuGroup(children: [
                        BuMenuRow(icon: LucideIcons.squarePen, label: 'Profili düzenle', onTap: () => _edit(p)),
                        BuMenuRow(
                          icon: LucideIcons.bookmark,
                          label: 'Kaydedilenler',
                          onTap: () => _go(SavedNewsPage(session: widget.session)),
                        ),
                        BuMenuRow(
                          icon: LucideIcons.calendar,
                          label: 'Etkinliklerim',
                          onTap: () => _go(MyEventsPage(session: widget.session)),
                        ),
                        BuMenuRow(
                          icon: LucideIcons.users,
                          label: 'Kulüplerim',
                          onTap: () => _go(MyClubsPage(session: widget.session)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      BuGroup(children: [
                        BuMenuRow(icon: LucideIcons.settings, label: 'Ayarlar', onTap: _openSettings),
                        BuMenuRow(
                          icon: LucideIcons.logOut,
                          label: 'Çıkış yap',
                          danger: true,
                          onTap: _confirmSignOut,
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final name = profile['displayName'] as String?;
    final url = fileUrl(profile['avatarUrl'] as String?);
    final year = (profile['classYear'] as num?)?.toInt();
    final tag = [
      profile['faculty'],
      profile['department'],
      if (year != null && year > 0) '$year. sınıf',
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final bio = (profile['bio'] as String?) ?? '';
    final initials = Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: t.hero),
      child: Text(initialsOf(name),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
    );
    return BuCard(
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (url == null)
                initials
              else
                ClipOval(
                  child: Image.network(url,
                      width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: t.ink)),
                    const SizedBox(height: 2),
                    Text((profile['email'] as String?) ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.mut)),
                    if (tag.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      BuBadge(tag, soft: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(bio, style: TextStyle(fontSize: 14, height: 1.45, color: t.mut)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String? value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(value ?? '–', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.ink)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: t.mut)),
          ],
        ),
      ),
    );
  }
}
