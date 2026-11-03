import 'package:flutter/material.dart';

import '../../widgets/bu.dart';

/// Inbox card with category artwork, inline actions and a trailing unread marker.
class NotifRow extends StatelessWidget {
  const NotifRow({
    super.key,
    required this.title,
    required this.typeLabel,
    required this.time,
    required this.unread,
    required this.onTap,
    this.body = '',
    this.unreadLabel,
    this.icon = BuIcons.bell,
    this.avatar,
    this.actions = const [],
    this.critical = false,
  });

  final String title, typeLabel, time, body;
  final bool unread, critical;
  final VoidCallback onTap;
  final String? unreadLabel;
  final IconData icon;
  final Widget? avatar;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final accent = critical ? t.danger : t.pr;
    final radius = BorderRadius.circular(22);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: [
          if (unread && unreadLabel != null) unreadLabel!,
          typeLabel,
          time
        ].where((s) => s.isNotEmpty).join(', '),
        child: Material(
          color: unread ? t.sf : t.sf2,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              decoration: critical
                  ? BoxDecoration(
                      border:
                          Border(top: BorderSide(color: t.danger, width: 3)))
                  : null,
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ExcludeSemantics(
                    child: avatar ??
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: accent.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(15)),
                          child: Icon(icon, size: 24, color: accent),
                        )),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Text(typeLabel,
                                style: BuType.caption
                                    .copyWith(fontSize: 11, color: t.mut)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(time,
                                  style: BuType.caption
                                      .copyWith(fontSize: 11, color: t.mut)),
                              const SizedBox(width: 4),
                              AnimatedContainer(
                                key: const ValueKey('notif-unread-dot'),
                                duration: BuMotion.of(context, BuMotion.short),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: unread ? t.pr : Colors.transparent,
                                    shape: BoxShape.circle),
                              ),
                            ]),
                          ]),
                      const SizedBox(height: 4),
                      Text(title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: BuType.caption.copyWith(
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: t.ink)),
                      if (body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(body,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.caption.copyWith(
                                  fontSize: 14, height: 1.4, color: t.mut)),
                        ),
                      if (actions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                              spacing: 8, runSpacing: 4, children: actions),
                        ),
                    ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
