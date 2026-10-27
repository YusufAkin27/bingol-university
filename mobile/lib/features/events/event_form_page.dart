import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/platform/image_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/typography.dart';
import '../../widgets/bu_widgets.dart';
import 'event_cover.dart';

/// Görsel seçici: kaynak verilir, hazırlanmış görsel (ya da iptalde null) döner. Testte değiştirilebilir.
typedef CoverPicker = Future<PreparedImage?> Function(ImageSource source);

/// Kapak yükleyici: `PUT /events/{id}/cover`. Testte değiştirilebilir.
typedef CoverUploader = Future<dynamic> Function(String path, PreparedImage image);

/// Kapağı yükler; başarısızsa "Tekrar dene" eylemli bildirim gösterir (sessizce yutmaz). Başarıyı döner.
Future<bool> uploadEventCover({
  required ScaffoldMessengerState messenger,
  required Session session,
  required int eventId,
  required PreparedImage image,
  required bool eventAlreadyCreated,
  CoverUploader? uploader,
}) async {
  final up = uploader ??
      (path, img) => MultipartUploader(session).upload(path, img, method: 'PUT');
  try {
    await up('/events/$eventId/cover', image);
    return true;
  } catch (e) {
    final reason = e is ApiError && !e.isNetwork && e.message.isNotEmpty ? ' ${e.message}' : '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(eventAlreadyCreated
            ? 'Etkinlik oluşturuldu, kapak yüklenemedi.$reason'
            : 'Kapak yüklenemedi.$reason'),
        action: SnackBarAction(
          label: 'Tekrar dene',
          onPressed: () => uploadEventCover(
            messenger: messenger,
            session: session,
            eventId: eventId,
            image: image,
            eventAlreadyCreated: eventAlreadyCreated,
            uploader: uploader,
          ),
        ),
      ));
    return false;
  }
}

/// Etkinlik oluşturma / düzenleme. [event] verilirse düzenleme (PATCH), yoksa oluşturma (POST).
/// Kapak, etkinlik kaydedildikten SONRA ayrı uçla yüklenir. Kaydedilirse `true` ile kapanır.
class EventFormPage extends StatefulWidget {
  const EventFormPage({
    super.key,
    required this.session,
    this.event,
    this.communityId,
    this.pickCover,
    this.uploadCover,
  });

  final Session session;
  final Map<String, dynamic>? event;
  final int? communityId;
  final CoverPicker? pickCover;
  final CoverUploader? uploadCover;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _place = TextEditingController();
  final _cap = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  PreparedImage? _picked; // yeni seçilen kapak
  bool _removeCover = false;
  String? _existingCover;
  bool _busy = false;
  String? _error;

  late final ImageService _images = ImageService();

  bool get _editing => widget.event != null;
  int? get _id => (widget.event?['id'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = '${e['title'] ?? ''}';
      _desc.text = '${e['description'] ?? ''}';
      _place.text = '${e['location'] ?? ''}';
      final cap = (e['capacity'] as num?)?.toInt();
      if (cap != null) _cap.text = '$cap';
      _existingCover = fileUrl(e['coverUrl'] as String?);
    }
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day + 1, 18);
    _start = DateTime.tryParse('${e?['startsAt']}')?.toLocal() ?? base;
    _end = DateTime.tryParse('${e?['endsAt']}')?.toLocal() ?? _start.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _place.dispose();
    _cap.dispose();
    super.dispose();
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---- kapak ----

  Future<PreparedImage?> _pick(ImageSource s) =>
      widget.pickCover != null ? widget.pickCover!(s) : _images.pickPrepared(s);

  Future<void> _chooseCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BuMenuRow(
              icon: LucideIcons.image,
              label: 'Galeriden seç',
              showChevron: false,
              onTap: () => Navigator.pop(c, ImageSource.gallery)),
          BuMenuRow(
              icon: LucideIcons.camera,
              label: 'Fotoğraf çek',
              showChevron: false,
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final img = await _pick(source);
      if (img != null && mounted) {
        setState(() {
          _picked = img;
          _removeCover = false;
        });
      }
    } on ImageException catch (e) {
      _toast(e.code == 'TOO_LARGE'
          ? 'Görsel çok büyük, daha küçük bir görsel seçin.'
          : e.code == 'UNSUPPORTED_TYPE'
              ? 'Yalnızca JPEG, PNG veya WebP görseller yüklenebilir.'
              : 'Görsel okunamadı.');
    } catch (_) {
      _toast('Görsel seçilemedi. İzinleri kontrol edin.');
    }
  }

  void _clearCover() => setState(() {
        if (_picked != null) {
          _picked = null;
        } else {
          _removeCover = true;
        }
      });

  // ---- tarih ----

  Future<void> _pickDate(bool start) async {
    final cur = start ? _start : _end;
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(cur));
    if (t == null || !mounted) return;
    final v = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      if (start) {
        final len = _end.difference(_start);
        _start = v;
        if (!_end.isAfter(_start)) _end = _start.add(len.isNegative || len == Duration.zero ? const Duration(hours: 2) : len);
      } else {
        _end = v;
      }
    });
  }

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // ---- kaydet ----

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'Başlık en az 3 karakter olmalı.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'Bitiş, başlangıçtan sonra olmalı.');
      return;
    }
    final capText = _cap.text.trim();
    final cap = capText.isEmpty ? null : int.tryParse(capText);
    if (capText.isNotEmpty && (cap == null || cap < 1)) {
      setState(() => _error = 'Kontenjan 1 veya daha büyük bir sayı olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final api = widget.session.api;
    try {
      var id = _id;
      var coverOk = true;
      if (_editing) {
        await api.patch('/events/$id', {
          'title': title,
          'description': _desc.text.trim(),
          'startsAt': _start.toUtc().toIso8601String(),
          'endsAt': _end.toUtc().toIso8601String(),
          'location': _place.text.trim(),
          'capacity': cap ?? 0,
        });
      } else {
        final r = await api.post('/events', {
          'title': title,
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          'startsAt': _start.toUtc().toIso8601String(),
          'endsAt': _end.toUtc().toIso8601String(),
          if (_place.text.trim().isNotEmpty) 'location': _place.text.trim(),
          if (cap != null) 'capacity': cap,
          if (widget.communityId != null) 'communityId': widget.communityId,
        });
        id = r is Map ? (r['id'] as num?)?.toInt() : null;
      }
      // Etkinlik kaydedildi; kapak hatası etkinliği geri almaz, ayrıca bildirilir.
      if (id != null) {
        if (_picked != null) {
          coverOk = await uploadEventCover(
            messenger: messenger,
            session: widget.session,
            eventId: id,
            image: _picked!,
            eventAlreadyCreated: !_editing,
            uploader: widget.uploadCover,
          );
        } else if (_removeCover && _editing) {
          try {
            await api.delete('/events/$id/cover');
          } catch (e) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text('Kapak kaldırılamadı. ${errorText(e)}')));
          }
        }
      }
      if (!mounted) return;
      // Kapak hatası bildirimi varsa üstüne yazılmaması için yalnızca başarılıysa gösterilir.
      if (!_editing && coverOk) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Etkinlik oluşturuldu.')));
      }
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          BuHeader(
            title: _editing ? 'Etkinliği düzenle' : 'Yeni etkinlik',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _coverBox(t),
                const SizedBox(height: 18),
                _label(t, 'Başlık'),
                TextField(
                  controller: _title,
                  maxLength: 150,
                  textCapitalization: TextCapitalization.sentences,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: const InputDecoration(hintText: 'Etkinlik başlığı', counterText: ''),
                ),
                const SizedBox(height: 14),
                _label(t, 'Açıklama'),
                TextField(
                  controller: _desc,
                  maxLength: 2000,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: const InputDecoration(hintText: 'Etkinlik hakkında kısaca', counterText: ''),
                ),
                const SizedBox(height: 14),
                _label(t, 'Başlangıç'),
                _dateRow(t, _fmt(_start), () => _pickDate(true), 'Başlangıç zamanı'),
                const SizedBox(height: 10),
                _label(t, 'Bitiş'),
                _dateRow(t, _fmt(_end), () => _pickDate(false), 'Bitiş zamanı'),
                const SizedBox(height: 14),
                _label(t, 'Mekân'),
                TextField(
                  controller: _place,
                  maxLength: 200,
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: const InputDecoration(hintText: 'Örn. Konferans Salonu', counterText: ''),
                ),
                const SizedBox(height: 14),
                _label(t, 'Kontenjan'),
                TextField(
                  controller: _cap,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: BuType.body.copyWith(color: t.ink),
                  decoration: const InputDecoration(hintText: 'Boş bırakırsan sınırsız'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: BuType.label.copyWith(color: t.danger)),
                ],
                const SizedBox(height: 20),
                BuButton(label: _editing ? 'Kaydet' : 'Etkinliği oluştur', busy: _busy, onPressed: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuTokens t, String s) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(s, style: BuType.label.copyWith(color: t.mut)),
      );

  Widget _dateRow(BuTokens t, String text, VoidCallback onTap, String semantics) {
    return Semantics(
      button: true,
      label: semantics,
      child: BuCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        onTap: onTap,
        child: Row(children: [
          Icon(LucideIcons.calendar, size: 18, color: t.mut),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: BuType.body.copyWith(color: t.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  /// 16:9 minimal kapak kutusu: boşken "Kapak fotoğrafı ekle", doluyken önizleme + değiştir/kaldır.
  Widget _coverBox(BuTokens t) {
    final Uint8List? bytes = _picked?.bytes;
    final existing = _removeCover ? null : _existingCover;
    final has = bytes != null || existing != null;
    final radius = BorderRadius.circular(18);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!has)
              Semantics(
                button: true,
                label: 'Kapak fotoğrafı ekle',
                child: Material(
                  color: t.soft,
                  child: InkWell(
                    onTap: _busy ? null : _chooseCover,
                    child: DecoratedBox(
                      decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: t.bd)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(LucideIcons.camera, size: 22, color: t.onSoft),
                            const SizedBox(width: 10),
                            Icon(LucideIcons.image, size: 22, color: t.onSoft),
                          ]),
                          const SizedBox(height: 8),
                          Text('Kapak fotoğrafı ekle', style: BuType.label.copyWith(color: t.onSoft)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (bytes != null)
              Image.memory(bytes,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => ColoredBox(color: t.soft))
            else
              EventCoverImage(url: existing!),
            if (has)
              Positioned(
                top: 8,
                right: 8,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _glass(LucideIcons.pencil, 'Kapağı değiştir', _busy ? null : _chooseCover),
                  const SizedBox(width: 8),
                  _glass(LucideIcons.trash2, 'Kapağı kaldır', _busy ? null : _clearCover),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _glass(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.black.withValues(alpha: .45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: Colors.white)),
          ),
        ),
      );
}

const _months = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];
