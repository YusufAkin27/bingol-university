import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart' show LucideIcons;
import 'post_models.dart';
import 'social_api.dart';

/// Gönderi yer imi düğmesi: iyimser günceller (PUT/DELETE `/posts/{id}/save`), hata olursa geri alır.
class SaveButton extends StatefulWidget {
  const SaveButton({super.key, required this.session, required this.post, required this.onChanged});

  final Session session;
  final Post post;
  final ValueChanged<Post> onChanged;

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.selectionClick();
    final before = widget.post;
    final want = !before.savedByMe;
    widget.onChanged(before.copyWith(savedByMe: want));
    final messenger = ScaffoldMessenger.maybeOf(context);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.save(before.id) : api.unsave(before.id));
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(SnackBar(
          content: Text(want ? 'Kaydedilenlere eklendi' : 'Kaydedilenlerden çıkarıldı'),
          duration: const Duration(seconds: 2)));
    } catch (e) {
      widget.onChanged(before);
      messenger?.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final saved = widget.post.savedByMe;
    return Semantics(
      button: true,
      toggled: saved,
      label: saved ? 'Kaydedilenlerden çıkar' : 'Kaydet',
      child: InkWell(
        key: const ValueKey('saveButton'),
        borderRadius: BorderRadius.circular(20),
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(saved ? Icons.bookmark : LucideIcons.bookmark, size: 20, color: saved ? t.pr : t.mut),
        ),
      ),
    );
  }
}
