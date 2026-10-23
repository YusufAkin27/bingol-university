import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Android emulator'de bilgisayarin localhost'u 10.0.2.2'dir.
const apiBase = 'http://10.0.2.2:8080/api';

void main() => runApp(const BingolApp());

Future<dynamic> getJson(String path) async {
  final res = await http.get(Uri.parse('$apiBase$path'));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return jsonDecode(utf8.decode(res.bodyBytes));
}

class BingolApp extends StatelessWidget {
  const BingolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingöl Üniversitesi',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  Map<String, dynamic> _status = {};

  static const _tabs = [
    ('HABER', 'Haberler', Icons.newspaper, 'NEWS'),
    ('DUYURU', 'Duyurular', Icons.campaign, 'NEWS'),
    ('ETKINLIK', 'Etkinlikler', Icons.event, 'NEWS'),
    ('MENU', 'Yemek', Icons.restaurant, 'MENU'),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await getJson('/status');
      if (mounted) setState(() => _status = Map<String, dynamic>.from(s));
    } catch (_) {
      // Durum alinamazsa bant gosterilmez; liste kendi hatasini gosterir.
    }
  }

  bool get _maintenance => _status[_tabs[_tab].$4]?['maintenance'] == true;

  @override
  Widget build(BuildContext context) {
    final t = _tabs[_tab];
    return Scaffold(
      appBar: AppBar(title: Text(t.$2)),
      body: Column(
        children: [
          if (_maintenance)
            MaterialBanner(
              content: const Text(
                  'Sistem şu anda bakımda. Son güncellenen bilgiler gösteriliyor.'),
              leading: const Icon(Icons.construction),
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: t.$1 == 'MENU'
                ? const MenuView()
                : NewsList(key: ValueKey(t.$1), type: t.$1),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _loadStatus();
        },
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$3), label: t.$2),
        ],
      ),
    );
  }
}

class NewsList extends StatefulWidget {
  final String type;
  const NewsList({super.key, required this.type});

  @override
  State<NewsList> createState() => _NewsListState();
}

class _NewsListState extends State<NewsList> {
  final _items = <Map<String, dynamic>>[];
  int _page = 0;
  bool _hasMore = true, _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refresh() async {
    _items.clear();
    _page = 0;
    _hasMore = true;
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await getJson('/news?type=${widget.type}&page=$_page&size=20');
      _items.addAll(List<Map<String, dynamic>>.from(r['items']));
      _page++;
      _hasMore = _page < (r['totalPages'] as int);
    } catch (e) {
      _error = 'Sunucuya ulaşılamadı';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(child: Text(_error ?? 'Henüz içerik yok'));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            _load();
            return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()));
          }
          final n = _items[i];
          return ListTile(
            leading: n['imageUrl'] == null
                ? null
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(n['imageUrl'],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 56, height: 56)),
                  ),
            title: Text(n['title'], maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(_fmtDate(n['publishedDate'])),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => NewsDetailPage(item: n))),
          );
        },
      ),
    );
  }
}

String _fmtDate(String? iso) {
  if (iso == null) return '';
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}.${p[1]}.${p[0]}' : iso;
}

class NewsDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  const NewsDetailPage({super.key, required this.item});

  Future<void> _openOriginal() =>
      launchUrl(Uri.parse(item['url']), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: getJson('/news/${item['id']}'),
      builder: (context, snap) {
        final d = snap.data as Map<String, dynamic>?;
        final content = d?['content'] as String?;
        return Scaffold(
          appBar: AppBar(title: Text(item['type'] == 'HABER' ? 'Haber' : 'Detay')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(item['title'], style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(_fmtDate(item['publishedDate'])),
              const SizedBox(height: 12),
              if (item['imageUrl'] != null)
                Image.network(item['imageUrl'],
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done)
                const Center(child: CircularProgressIndicator())
              else if (content != null && content.isNotEmpty)
                Text(content)
              else
                const Text('İçeriğin tamamı için kaynak sayfayı açın.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openOriginal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Kaynak sayfada aç'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MenuView extends StatefulWidget {
  const MenuView({super.key});

  @override
  State<MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<MenuView> {
  late Future<dynamic> _future = getJson('/menu');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return const Center(child: Text('Sunucuya ulaşılamadı'));
        final days = List<Map<String, dynamic>>.from(snap.data as List);
        if (days.isEmpty) {
          return const Center(child: Text('Bu ay için yemek listesi yok'));
        }
        final today = DateTime.now().toIso8601String().substring(0, 10);
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = getJson('/menu'));
            await _future;
          },
          child: ListView(
            children: [
              for (final d in days)
                Card(
                  color: d['date'] == today
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(_fmtDate(d['date']) +
                        (d['date'] == today ? '  (Bugün)' : '')),
                    subtitle: Text((d['items'] as List).join('\n')),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
