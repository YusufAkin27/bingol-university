import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'poll_api.dart';
import 'poll_models.dart';

/// Kulüp yöneticisi için anket oluşturma formu (başlık, seçenekler 2-12, tür, gizli oy, bitiş zamanı).
class PollFormPage extends StatefulWidget {
  const PollFormPage({super.key, required this.session, required this.communityId});

  final Session session;
  final int communityId;

  @override
  State<PollFormPage> createState() => _PollFormPageState();
}

class _PollFormPageState extends State<PollFormPage> {
  static const _maxOptions = 12;

  late final PollApi _api = PollApi(widget.session);
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final List<TextEditingController> _opts = [TextEditingController(), TextEditingController()];
  PollType _type = PollType.single;
  bool _anonymous = false;
  DateTime? _closesAt;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _closesAt = DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final base = _closesAt ?? now.add(const Duration(days: 7));
    final d = await showDatePicker(
        context: context, initialDate: base.isBefore(now) ? now : base, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (tm == null || !mounted) return;
    setState(() => _closesAt = DateTime(d.year, d.month, d.day, tm.hour, tm.minute));
  }

  Future<void> _submit() async {
    final opts = [for (final c in _opts) c.text];
    final err = validatePollDraft(title: _title.text, type: _type, options: opts, closesAt: _closesAt);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final p = await _api.createCommunity(
        communityId: widget.communityId,
        title: _title.text,
        description: _desc.text,
        type: _type,
        anonymous: _anonymous,
        closesAt: _closesAt!,
        options: [for (final o in opts) if (o.trim().isNotEmpty) o],
      );
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = pollErrorText(e);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          BuHeader(title: 'Anket oluştur', onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _label(t, 'Başlık'),
                TextField(
                  controller: _title,
                  maxLength: 140,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Örn. Yeni dönem başkanı seçimi'),
                ),
                const SizedBox(height: 8),
                _label(t, 'Açıklama (isteğe bağlı)'),
                TextField(
                  controller: _desc,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'Kısa bir açıklama'),
                ),
                const SizedBox(height: 8),
                _label(t, 'Tür'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  BuChip(label: 'Tek seçim', selected: _type == PollType.single, onTap: () => setState(() => _type = PollType.single)),
                  BuChip(label: 'Çoklu seçim', selected: _type == PollType.multi, onTap: () => setState(() => _type = PollType.multi)),
                  BuChip(label: 'Sıralı seçim', selected: _type == PollType.ranked, onTap: () => setState(() => _type = PollType.ranked)),
                  BuChip(label: 'Puanlama', selected: _type == PollType.rating, onTap: () => setState(() => _type = PollType.rating)),
                ]),
                if (_type != PollType.rating) ...[
                  const SizedBox(height: 16),
                  _label(t, 'Seçenekler (2-$_maxOptions)'),
                  for (var i = 0; i < _opts.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _opts[i],
                            maxLength: 80,
                            decoration: InputDecoration(hintText: 'Seçenek ${i + 1}', counterText: ''),
                          ),
                        ),
                        if (_opts.length > 2)
                          BuIconButton(
                            icon: LucideIcons.x,
                            size: 36,
                            tooltip: 'Seçeneği sil',
                            onTap: () => setState(() => _opts.removeAt(i).dispose()),
                          ),
                      ]),
                    ),
                  if (_opts.length < _maxOptions)
                    BuButton(
                      label: 'Seçenek ekle',
                      icon: LucideIcons.plus,
                      kind: BuButtonKind.soft,
                      compact: true,
                      onPressed: () => setState(() => _opts.add(TextEditingController())),
                    ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Gizli oy', style: BuType.bodyStrong.copyWith(color: t.ink)),
                  subtitle: Text('Kimin ne oy verdiği kimseye gösterilmez.', style: BuType.caption.copyWith(color: t.mut)),
                  value: _anonymous,
                  onChanged: (v) => setState(() => _anonymous = v),
                ),
                const SizedBox(height: 8),
                _label(t, 'Bitiş zamanı'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (name, days) in const [('1 gün', 1), ('3 gün', 3), ('7 gün', 7)])
                    BuChip(
                        label: name,
                        onTap: () => setState(() => _closesAt = DateTime.now().add(Duration(days: days)))),
                ]),
                const SizedBox(height: 8),
                BuCard(
                  onTap: _pickEnd,
                  child: Row(children: [
                    Icon(LucideIcons.clock, size: 16, color: t.mut),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_closesAt == null ? 'Tarih ve saat seç' : _fmt(_closesAt!),
                            style: BuType.bodyStrong.copyWith(color: t.ink))),
                    Text('Değiştir', style: BuType.label.copyWith(color: t.pr)),
                  ]),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                        liveRegion: true, child: Text(_error!, style: BuType.body.copyWith(color: t.danger))),
                  ),
                const SizedBox(height: 20),
                BuButton(label: 'Yayınla', busy: _busy, onPressed: _busy ? null : _submit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuTokens t, String s) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: BuType.label.copyWith(color: t.mut)));
}
