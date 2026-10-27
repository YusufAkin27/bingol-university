import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../widgets/bu_widgets.dart';
import '../posts/social_api.dart';

/// Takip Et / Takipten Çık düğmesi. İyimser günceller (PUT/DELETE `/users/{id}/follow`), hata olursa geri alır.
/// [onChanged] yeni durumla çağrılır (takipçi sayısı güncellemesi için).
class FollowButton extends StatefulWidget {
  const FollowButton({
    super.key,
    required this.session,
    required this.userId,
    required this.followed,
    this.onChanged,
    this.compact = true,
  });

  final Session session;
  final int userId;
  final bool followed;
  final ValueChanged<bool>? onChanged;
  final bool compact;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _followed = widget.followed;
  bool _busy = false;

  @override
  void didUpdateWidget(FollowButton old) {
    super.didUpdateWidget(old);
    if (old.followed != widget.followed && !_busy) _followed = widget.followed;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final want = !_followed;
    setState(() {
      _busy = true;
      _followed = want;
    });
    widget.onChanged?.call(want);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final api = SocialApi(widget.session);
    try {
      await (want ? api.follow(widget.userId) : api.unfollow(widget.userId));
    } catch (e) {
      if (mounted) setState(() => _followed = !want);
      widget.onChanged?.call(!want);
      messenger?.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: _followed,
      label: _followed ? 'Takipten çık' : 'Takip et',
      excludeSemantics: true,
      child: BuButton(
        key: const ValueKey('followButton'),
        label: _followed ? 'Takipte' : 'Takip et',
        icon: _followed ? LucideIcons.userCheck : LucideIcons.userPlus,
        kind: _followed ? BuButtonKind.outline : BuButtonKind.primary,
        compact: widget.compact,
        onPressed: _busy ? null : _toggle,
      ),
    );
  }
}
