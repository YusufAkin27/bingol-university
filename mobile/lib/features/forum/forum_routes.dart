import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'data/forum_models.dart';
import '../share/share_button.dart' show shareContentForComment, shareContentForTopic;
import '../share/share_sheet.dart' show showShareSheet;
import 'presentation/pages/create_topic_page.dart';
import 'presentation/pages/edit_topic_page.dart';
import 'presentation/pages/forum_activity_page.dart';
import 'presentation/pages/forum_home_page.dart';
import 'presentation/pages/forum_placeholder_page.dart';
import 'presentation/pages/forum_prefs_page.dart';
import 'presentation/pages/forum_saved_page.dart';
import 'presentation/pages/forum_search_page.dart';
import 'presentation/pages/topic_detail_page.dart';
import 'presentation/widgets/forum_author_actions.dart';
import 'presentation/widgets/report_sheet.dart';

export 'data/forum_api.dart' show ForumApi;
export 'data/forum_models.dart';

/// Kampüs Forum gezinme noktaları (TEK giriş). İmzalar SABİTTİR (FORUM_API.md §3); gerçek ekranı yazan ajan
/// yalnız kendi fonksiyonunun GÖVDESİNDEKİ `builder` satırını değiştirir. Yer tutucular
/// `ForumPlaceholderPage`'dir (görünür metin yok). Rota adları analitik/geri akışı için sabittir.

Future<T?> _push<T>(BuildContext context, String name, WidgetBuilder builder) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(settings: RouteSettings(name: name), builder: builder));

/// Forum ana sayfası (MB-A).
Future<void> openForumHome(BuildContext context, Session session) =>
    _push<void>(context, 'forum_home', (_) => ForumHomePage(session: session));

/// Konu detayı (MB-B). [commentId] verilirse açılışta o yoruma gidilir (bağlantı/bildirim). [initial] liste kartından
/// hızlı ilk çizim içindir. Sayfa kapanırken güncel [TopicSummary]'yi (beğeni/kaydet/yorum sayısı; silindiyse null)
/// `Navigator.pop` ile döndürür: liste kartı güncellenir. Yeni konu ise liste başına eklenir.
Future<TopicSummary?> openTopicDetail(BuildContext context, Session session, int topicId,
        {int? commentId, TopicSummary? initial}) =>
    _push<TopicSummary>(context, 'forum_topic', (_) => TopicDetailPage(session: session, topicId: topicId, commentId: commentId, initial: initial));

/// Yeni konu (MB-C). Başarıda konu detayına geçer; çağırana oluşan konunun özetini (iptalde null) döndürür.
/// [categoryId] varsa kategori önceden seçilir.
Future<TopicSummary?> openCreateTopic(BuildContext context, Session session, {int? categoryId}) =>
    _push<TopicSummary>(context, 'forum_create', (_) => CreateTopicPage(session: session, categoryId: categoryId));

/// Konu düzenle (MB-C). Kaydedilince güncel [TopicView] döner (iptalde null).
Future<TopicView?> openEditTopic(BuildContext context, Session session, TopicView topic) =>
    _push<TopicView>(context, 'forum_edit', (_) => EditTopicPage(session: session, topic: topic));

/// Forum araması (MB-D).
Future<void> openForumSearch(BuildContext context, Session session) =>
    _push<void>(context, 'forum_search', (_) => ForumSearchPage(session: session));

/// Kaydedilen konu/yorumlar (MB-D).
Future<void> openForumSaved(BuildContext context, Session session) =>
    _push<void>(context, 'forum_saved', (_) => ForumSavedPage(session: session));

/// Forum faaliyetim: Açtığım Konular, Yorumlarım, Kaydedilenler, Takip Ettiklerim (MB-D). [initialTab]: 0 konularım,
/// 1 yorumlarım, 2 kaydedilenler, 3 takip ettiklerim (profil menüsü satırları doğrudan ilgili sekmeyi açar).
Future<void> openMyForumActivity(BuildContext context, Session session, {int initialTab = 0}) =>
    _push<void>(context, 'forum_activity', (_) => ForumActivityPage(session: session, initialTab: initialTab));

/// Başkasının herkese açık forum faaliyeti (profil "Forum" bölümü): [initialTab] 0 konular, 1 yorumlar (MB-D).
Future<void> openUserForumActivity(BuildContext context, Session session, int userId, {String? name, int initialTab = 0}) =>
    _push<void>(context, 'forum_user_activity',
        (_) => ForumUserActivityPage(session: session, userId: userId, name: name, initialTab: initialTab));

/// Forum bildirim tercihleri (MB-D).
Future<void> openForumPrefs(BuildContext context, Session session) =>
    _push<void>(context, 'forum_prefs', (_) => ForumPrefsPage(session: session));

/// Konuyu paylaşır (mesajla / bağlantı / sistem paylaşımı): `https://bukampus.com.tr/s/f/{id}` (MB-D).
Future<void> openTopicShare(BuildContext context, Session session, TopicSummary topic) =>
    showShareSheet(context, session, shareContentForTopic(session, topic));

/// Yorum bağlantısını paylaşır: `https://bukampus.com.tr/s/fc/{id}` (MB-D). [topicTitle] kartta bağlam satırıdır.
Future<void> openCommentShare(BuildContext context, Session session, ForumComment comment, {String? topicTitle}) =>
    showShareSheet(context, session, shareContentForComment(session, comment, topicTitle: topicTitle));

/// Şikâyet alt sayfası (MB-D). [targetType]: [kForumReportTopic] | [kForumReportComment]. Gönderildiyse true döner.
Future<bool> openReportSheet(BuildContext context, Session session,
        {required String targetType, required int targetId, bool anonymousAuthor = false}) =>
    showForumReportSheet(context, session, targetType: targetType, targetId: targetId);

/// Konu/yorum yazarını engeller (onay + sonuç bildirimi). Yazar anonim olsa da çalışır; kimlik gösterilmez (MB-D).
/// [targetType]: [kForumReportTopic] | [kForumReportComment]. Engellendiyse true döner.
Future<bool> openBlockAuthor(BuildContext context, Session session, {required String targetType, required int targetId}) =>
    ForumAuthorActions.blockAuthor(context, session, targetType: targetType, targetId: targetId);

/// Kimliği bilinen (anonim olmayan) yazarı sessize alır (onay + sonuç bildirimi). Sessize alınanlar
/// Forum bildirim tercihleri sayfasında yönetilir (MB-D).
Future<bool> openMuteUser(BuildContext context, Session session, {required int userId, required String name}) =>
    ForumAuthorActions.muteUser(context, session, userId: userId, name: name);
