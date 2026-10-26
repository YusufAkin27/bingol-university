import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import 'support_common.dart';

/// Geri bildirim formu + gönderdiklerim listesi (imleçli).
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, required this.session, this.initialCategory = 'BUG'});

  final Session session;
  final String initialCategory;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category = widget.initialCategory;
  bool _busy = false;
  String? _formError;

  final List<Map<String, dynamic>> _mine = [];
  int? _next;
  bool _loadingMine = true;
  bool _more = false;
  Object? _mineError;

  @override
  void initState() {
    super.initState();
    _loadMine(reset: true);
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMine({bool reset = false}) async {
    if (!reset) {
      if (_next == null || _more) return;
      setState(() => _more = true);
    }
    try {
      final q = !reset && _next != null ? '&cursor=$_next' : '';
      final r = await widget.session.api.get('/feedback/mine?size=20$q') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (reset) _mine.clear();
        _mine.addAll(((r['items'] as List?) ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()));
        _next = (r['nextCursor'] as num?)?.toInt();
        _mineError = null;
        _loadingMine = false;
        _more = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mineError = e;
        _loadingMine = false;
        _more = false;
      });
    }
  }

  Future<void> _submit() async {
    final s = _subject.text.trim();
    final m = _message.text.trim();
    if (s.isEmpty || m.isEmpty) {
      setState(() => _formError = 'Konu ve mesaj alanlarını doldurun.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await widget.session.api.post('/feedback', {
        'category': _category,
        'subject': s,
        'message': m,
        'platform': 'ANDROID',
      });
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      supportSnack(context, 'Geri bildiriminiz için teşekkürler.');
      setState(() => _busy = false);
      _loadMine(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _formError = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(title: 'Geri bildirim', onBack: () => Navigator.pop(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadMine(reset: true),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              const SupportLabel('KATEGORİ', form: true),
              SupportChoices(
                  options: supportFeedbackCategories,
                  value: _category,
                  onChanged: (v) => setState(() => _category = v)),
              const SupportLabel('KONU', form: true),
              SupportField(controller: _subject, hint: 'Kısaca konu', maxLength: 120),
              const SupportLabel('MESAJ', form: true),
              SupportField(
                  controller: _message, hint: 'Görüşünüzü yazın', maxLength: 2000, minLines: 4, maxLines: 8),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_formError!, style: TextStyle(color: t.danger, fontSize: 13)),
                ),
              const SizedBox(height: 16),
              BuButton(label: 'Gönder', icon: LucideIcons.send, busy: _busy, onPressed: _submit),
              const SupportLabel('GÖNDERDİKLERİM', form: true),
              ..._mineList(t),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _mineList(BuTokens t) {
    if (_loadingMine) {
      return [const Padding(padding: EdgeInsets.all(24), child: LoadingView())];
    }
    if (_mineError != null && _mine.isEmpty) {
      return [SizedBox(height: 200, child: ErrorView(error: _mineError!, onRetry: () => _loadMine(reset: true)))];
    }
    if (_mine.isEmpty) {
      return [
        const SizedBox(
            height: 160,
            child: EmptyView(icon: LucideIcons.messageCircle, text: 'Henüz geri bildirim göndermediniz.'))
      ];
    }
    return [
      for (final f in _mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: BuCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('${f['subject'] ?? ''}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.ink)),
                ),
                const SizedBox(width: 8),
                SupportFeedbackPill(f['status'] as String?),
              ]),
              const SizedBox(height: 2),
              Text('${supportFeedbackCategories[f['category']] ?? 'Diğer'} · ${niceDate(f['createdAt'] as String?)}',
                  style: TextStyle(fontSize: 12, color: t.mut)),
              const SizedBox(height: 6),
              Text('${f['message'] ?? ''}', style: TextStyle(fontSize: 13, height: 1.4, color: t.ink)),
              if ((f['adminResponse'] as String?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text('${f['adminResponse']}', style: TextStyle(fontSize: 13, height: 1.4, color: t.onSoft)),
                ),
              ],
            ]),
          ),
        ),
      if (_next != null)
        Center(
          child: BuButton(
              label: 'Daha fazla', kind: BuButtonKind.outline, compact: true, busy: _more, onPressed: _loadMine),
        ),
    ];
  }
}
