import 'package:flutter/material.dart';

import '../icons/bu_icons.dart';
import '../locale_controller.dart';
import 'push_targets.dart';

/// Display hints only; navigation and authorization remain in PushRouter/the API.
enum NotificationCategory {
  event,
  announcement,
  academic,
  poll,
  social,
  system
}

NotificationCategory notificationCategory(Map<String, dynamic> data) {
  final explicit = '${data['category'] ?? ''}'.toUpperCase();
  for (final c in NotificationCategory.values) {
    if (c.name.toUpperCase() == explicit) return c;
  }
  final type = '${data['type'] ?? ''}'.toUpperCase();
  final subtype = '${data['subtype'] ?? ''}'.toUpperCase();
  final target = resolvePushTarget(data).dest;
  if (target == PushDest.poll || subtype == 'POLL') {
    return NotificationCategory.poll;
  }
  if (target == PushDest.exams ||
      target == PushDest.timetable ||
      subtype == 'EXAM_REMINDER') {
    return NotificationCategory.academic;
  }
  if (target == PushDest.event || type == 'EVENT') {
    return NotificationCategory.event;
  }
  if (isForumPush(data)) return NotificationCategory.social;
  if (type.startsWith('POST_') ||
      type == 'COMMENT_REPLY' ||
      type == 'USER_FOLLOW' ||
      type.startsWith('FOLLOW') ||
      target == PushDest.user ||
      target == PushDest.followRequests) {
    return NotificationCategory.social;
  }
  if (type == 'SYSTEM' || target == PushDest.accountSecurity) {
    return NotificationCategory.system;
  }
  return NotificationCategory.announcement;
}

String notificationCategoryLabel(
    BuildContext context, NotificationCategory category) {
  final l = context.l10n;
  return switch (category) {
    NotificationCategory.event => l.bildirimTypeEvent,
    NotificationCategory.announcement => l.bildirimmobilKanalAnnouncement,
    NotificationCategory.academic => l.profileAcademic,
    NotificationCategory.poll => l.bildirimTypePoll,
    NotificationCategory.social => l.profilePrefsSocial,
    NotificationCategory.system => l.profil1AccountSecurity,
  };
}

IconData notificationIcon(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}'.toUpperCase();
  if (isForumPush(data)) return BuIcons.messageSquareText;
  final dest = resolvePushTarget(data).dest;
  if (dest == PushDest.ticket || dest == PushDest.feedback) {
    return Icons.support_agent;
  }
  if (type == 'POST_LIKE') return Icons.favorite_outline;
  if (type == 'POST_MENTION') return Icons.alternate_email;
  if (type == 'FOLLOW_REQUEST' || type == 'USER_FOLLOW') {
    return Icons.person_add_alt_1_outlined;
  }
  if (type == 'FOLLOW_ACCEPTED') return Icons.how_to_reg_outlined;
  return switch (notificationCategory(data)) {
    NotificationCategory.event => Icons.event_outlined,
    NotificationCategory.announcement => Icons.campaign_outlined,
    NotificationCategory.academic => Icons.school_outlined,
    NotificationCategory.poll => Icons.poll_outlined,
    NotificationCategory.social => Icons.people_outline,
    NotificationCategory.system => Icons.shield_outlined,
  };
}
