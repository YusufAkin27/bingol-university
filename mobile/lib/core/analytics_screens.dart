import 'package:flutter/material.dart';

import '../features/academic/academic_calendar_page.dart';
import '../features/academic/academic_hub_page.dart';
import '../features/academic/announcements_page.dart';
import '../features/academic/course_form_page.dart';
import '../features/academic/exam_form_page.dart';
import '../features/academic/exams_page.dart';
import '../features/academic/reminder_settings_page.dart';
import '../features/academic/timetable_page.dart';
import '../features/auth/forgot_password_page.dart';
import '../features/auth/help/about_page.dart';
import '../features/auth/help/help_code_page.dart';
import '../features/auth/help/help_form_page.dart';
import '../features/auth/help/help_track_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/new_password_page.dart';
import '../features/auth/permissions_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/reset_code_page.dart';
import '../features/auth/reset_success_page.dart';
import '../features/auth/verify_code_page.dart';
import '../features/auth/welcome_page.dart';
import '../features/campus_map/campus_category_page.dart';
import '../features/campus_map/campus_map_page.dart';
import '../features/campus_map/campus_place_page.dart';
import '../features/campus_map/campus_search_page.dart';
import '../features/chat/chat_background_settings_page.dart';
import '../features/chat/chat_detail_page.dart';
import '../features/chat/chat_info_media.dart';
import '../features/chat/chat_info_members.dart';
import '../features/chat/chat_info_page.dart';
import '../features/chat/chat_media_viewer.dart';
import '../features/chat/chat_video_player.dart';
import '../features/chat/contacts_match_page.dart';
import '../features/chat/media_camera_page.dart';
import '../features/chat/media_picker_page.dart';
import '../features/chat/media_preview_page.dart';
import '../features/chat/message_bubble.dart' show ChatImageViewer;
import '../features/chat/message_requests_page.dart';
import '../features/chat/new_chat_page.dart';
import '../features/chat/view_once_viewer.dart';
import '../features/clubs/club_detail_page.dart';
import '../features/clubs/club_form_page.dart';
import '../features/clubs/club_members_page.dart';
import '../features/clubs/club_requests_page.dart';
import '../features/events/etkinlik2_attendance_page.dart';
import '../features/events/etkinlik2_qr_page.dart';
import '../features/events/etkinlik2_requests_page.dart';
import '../features/events/etkinlik2_settings_page.dart';
import '../features/events/event_detail_page.dart';
import '../features/events/event_form_page.dart';
import '../features/events/events_page.dart';
import '../features/follow/follow_list_page.dart';
import '../features/follow/follow_requests_page.dart';
import '../features/follow/follow_suggestions.dart';
import '../features/home/home_layout_sheet.dart';
import '../features/legal/legal_reaccept_page.dart';
import '../features/media_crop/crop_page.dart';
import '../features/menu/menu_page.dart';
import '../features/news/news_detail_page.dart';
import '../features/news/news_list_page.dart';
import '../features/notifications/notifications_page.dart';
import '../features/notifications/push_help_page.dart';
import '../features/platform/qr_scan_page.dart';
import '../features/polls/poll_detail_page.dart';
import '../features/polls/poll_form_page.dart';
import '../features/polls/poll_list_page.dart';
import '../features/posts/compose_post_page.dart';
import '../features/posts/post_detail_page.dart';
import '../features/posts/user_posts_page.dart';
import '../features/profile/account_security_page.dart';
import '../features/profile/blocked_users_page.dart';
import '../features/profile/edit_profile_page.dart';
import '../features/profile/legal_pages.dart';
import '../features/profile/my_clubs_page.dart';
import '../features/profile/my_events_page.dart';
import '../features/profile/notification_prefs_page.dart';
import '../features/profile/privacy_data_page.dart';
import '../features/profile/profil2_delete_account_page.dart';
import '../features/profile/profil2_my_data_page.dart';
import '../features/profile/saved_news_page.dart';
import '../features/profile/settings_page.dart';
import '../features/profile/user_profile_page.dart';
import '../features/search/search_page.dart';
import '../features/support/support_feedback_page.dart';
import '../features/support/support_new_ticket_page.dart';
import '../features/support/support_page.dart';
import '../features/support/support_suggestions_page.dart';
import '../features/support/support_ticket_page.dart';
import '../widgets/academic_pickers.dart';

/// Ekran anahtarları: `screen_view` olayının `screen` değeri. Anahtarlar KARARLIDIR (analitik geçmişi bunlara
/// bağlıdır): bir sınıfı yeniden adlandırınca burada eşlemeyi koruyun, anahtarı değiştirmeyin.
///
/// Neden tür sabitleri (`Type` anahtarlı harita)? Rotalar çoğunlukla adsız `MaterialPageRoute`'tur; sürüm
/// derlemeleri `--obfuscate` ile derlendiği için `runtimeType.toString()` güvenilmezdir, oysa `Type`
/// eşitliği gizleme altında da çalışır. Yeni ekran = aşağıya bir satır (`screen_keys_test` kontrol eder).

/// Kök rota (`/`): anahtarı alt gezinme sekmesinden gelir (bkz. [kTabScreens]).
const kRootScreen = '@root';

/// Alt gezinme sekmeleri (AppTab sırası): sekme geçişi rota değildir, ayrıca izlenir.
const kTabScreens = ['home', 'discover', 'chat', 'clubs', 'profile'];

/// Eşlenmemiş tam ekran sayfa.
const kOtherScreen = 'other';

final Map<Type, String> _widgetKeys = {
  // Akademik
  AcademicCalendarPage: 'academic_calendar',
  AcademicHubPage: 'academic_hub',
  AnnouncementsPage: 'announcements',
  AnnouncementDetailPage: 'announcement_detail',
  CourseFormPage: 'course_form',
  ExamFormPage: 'exam_form',
  ExamsPage: 'exams',
  ReminderSettingsPage: 'reminder_settings',
  TimetablePage: 'timetable',
  // Kimlik doğrulama / yardım
  WelcomePage: 'welcome',
  LoginPage: 'login',
  RegisterPage: 'register',
  VerifyCodePage: 'verify_code',
  ForgotPasswordPage: 'forgot_password',
  ResetCodePage: 'reset_code',
  NewPasswordPage: 'new_password',
  ResetSuccessPage: 'reset_success',
  PermissionsPage: 'permissions',
  AboutPage: 'about',
  HelpCodePage: 'help_code',
  HelpFormPage: 'help_form',
  HelpTrackPage: 'help_track',
  LegalReacceptPage: 'legal_reaccept',
  // Sohbet
  ChatBackgroundSettingsPage: 'chat_background',
  ChatDetailPage: 'chat_detail',
  ChatMediaGridPage: 'chat_media_grid',
  ChatMembersPage: 'chat_members',
  ChatInfoPage: 'chat_info',
  ChatMediaViewer: 'chat_media_viewer',
  ChatImageViewer: 'chat_image_viewer',
  ViewOnceViewer: 'view_once_viewer',
  ChatVideoPlayerPage: 'chat_video',
  ContactsMatchPage: 'contacts_match',
  MediaCameraPage: 'media_camera',
  MediaPickerPage: 'media_picker',
  MediaPreviewPage: 'media_preview',
  MessageRequestsPage: 'message_requests',
  NewChatPage: 'new_chat',
  // Kulüpler
  ClubDetailPage: 'club_detail',
  ClubFormPage: 'club_form',
  ClubMembersPage: 'club_members',
  ClubRequestsPage: 'club_requests',
  // Etkinlikler
  EventsPage: 'events',
  EventDetailPage: 'event_detail',
  EventFormPage: 'event_form',
  Etkinlik2AttendancePage: 'event_attendance',
  Etkinlik2QrPage: 'event_qr',
  Etkinlik2RequestsPage: 'event_requests',
  Etkinlik2SettingsPage: 'event_settings',
  QrScanPage: 'qr_scan',
  // Takip / ana sayfa / diğer
  FollowListPage: 'follow_list',
  FollowRequestsPage: 'follow_requests',
  FollowSuggestionsPage: 'follow_suggestions',
  HomeLayoutPage: 'home_layout',
  CropPage: 'crop',
  MenuPage: 'menu',
  NewsListPage: 'news_list',
  NewsDetailPage: 'news_detail',
  NotificationsPage: 'notifications',
  PushHelpPage: 'push_help',
  SearchPage: 'search',
  // Kampüs haritası
  CampusMapPage: 'campus_map',
  CampusSearchPage: 'campus_search',
  CampusCategoryPage: 'campus_category',
  CampusPlacePage: 'campus_place',
  // Anketler
  PollListPage: 'poll_list',
  PollDetailPage: 'poll_detail',
  PollFormPage: 'poll_form',
  // Gönderiler
  ComposePostPage: 'compose_post',
  PostDetailPage: 'post_detail',
  UserPostsPage: 'user_posts',
  // Profil / ayarlar
  AccountSecurityPage: 'account_security',
  BlockedUsersPage: 'blocked_users',
  EditProfilePage: 'edit_profile',
  LegalListPage: 'legal_list',
  LegalDocPage: 'legal_doc',
  MyClubsPage: 'my_clubs',
  MyEventsPage: 'my_events',
  NotificationPrefsPage: 'notification_prefs',
  PrivacyDataPage: 'privacy_data',
  DeleteAccountPage: 'delete_account',
  MyDataPage: 'my_data',
  SavedNewsPage: 'saved_news',
  SettingsPage: 'settings',
  UserProfilePage: 'user_profile',
  // Destek
  FeedbackPage: 'feedback',
  NewTicketPage: 'new_ticket',
  SupportPage: 'support',
  SuggestionsPage: 'suggestions',
  SuggestionDetailPage: 'suggestion_detail',
  SupportTicketPage: 'support_ticket',
  // Ortak
  DepartmentPickerPage: 'department_picker',
};

/// Test için salt okunur görünüm.
@visibleForTesting
Map<Type, String> get screenWidgetKeys => Map.unmodifiable(_widgetKeys);

final RegExp _keyRe = RegExp(r'^[a-z0-9_]{1,40}$');

/// Herhangi bir adı `[a-z0-9_]{1,40}` biçimine getirir; boş kalırsa null.
String? normalizeScreenKey(String? raw) {
  if (raw == null) return null;
  var s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.length > 40) s = s.substring(0, 40);
  return s.isEmpty ? null : s;
}

bool isValidScreenKey(String s) => _keyRe.hasMatch(s);

/// Sayfa widget'ının ekran anahtarı; bilinmiyorsa `other`. `Scaffold(body: X)` sarmalı bir kat açılır.
String screenKeyForWidget(Widget w) {
  final direct = _widgetKeys[w.runtimeType];
  if (direct != null) return direct;
  if (w is Scaffold && w.body != null) return _widgetKeys[w.body.runtimeType] ?? kOtherScreen;
  return kOtherScreen;
}

/// Rotanın ekran anahtarı; tam ekran sayfa DEĞİLSE (diyalog, alt sayfa, açılır menü) null → izlenmez.
/// Kök rota [kRootScreen] döner. Sayfa oluşturucusu çağrılamazsa `other`.
String? screenKeyForRoute(Route<dynamic> route, BuildContext context) {
  if (route is! PageRoute) return null;
  if (route.settings.name == '/') return kRootScreen;
  try {
    Widget? page;
    if (route is MaterialPageRoute) {
      page = route.builder(context);
    } else if (route is PageRouteBuilder) {
      page = route.pageBuilder(context, kAlwaysCompleteAnimation, kAlwaysDismissedAnimation);
    }
    if (page != null) {
      final k = screenKeyForWidget(page);
      if (k != kOtherScreen) return k;
    }
  } catch (_) {
    // Oluşturucu bağlama ihtiyaç duyabilir: ekran 'other' sayılır, uygulama etkilenmez.
  }
  final named = normalizeScreenKey(route.settings.name);
  return named ?? kOtherScreen;
}
