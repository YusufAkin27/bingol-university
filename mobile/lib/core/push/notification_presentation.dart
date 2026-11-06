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
  if (type == 'SYSTEM' || target == PushDest.accountSecurity || target == PushDest.devices) {
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
    return BuIcons.headset;
  }
  if (type == 'POST_LIKE') return BuIcons.heart;
  if (type == 'POST_MENTION') return BuIcons.atSign;
  if (type == 'FOLLOW_REQUEST' || type == 'USER_FOLLOW') {
    return BuIcons.userPlus;
  }
  if (type == 'FOLLOW_ACCEPTED') return BuIcons.userCheck;
  return switch (notificationCategory(data)) {
    NotificationCategory.event => BuIcons.calendar,
    NotificationCategory.announcement => BuIcons.megaphone,
    NotificationCategory.academic => BuIcons.graduationCap,
    NotificationCategory.poll => BuIcons.vote,
    NotificationCategory.social => BuIcons.users,
    NotificationCategory.system => BuIcons.shield,
  };
}
