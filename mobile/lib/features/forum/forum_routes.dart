import 'package:flutter/material.dart';

import '../../core/session.dart';
import 'data/forum_models.dart';
import 'presentation/pages/create_topic_page.dart';
import 'presentation/pages/edit_topic_page.dart';
import 'presentation/pages/forum_home_page.dart';
import 'presentation/pages/forum_placeholder_page.dart';

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
    _push<TopicSummary>(context, 'forum_topic', (_) => const ForumPlaceholderPage(name: 'forum_topic'));

/// Yeni konu (MB-C). Başarıda konu detayına geçer; çağırana oluşan konunun özetini (iptalde null) döndürür.
/// [categoryId] varsa kategori önceden seçilir.
Future<TopicSummary?> openCreateTopic(BuildContext context, Session session, {int? categoryId}) =>
    _push<TopicSummary>(context, 'forum_create', (_) => CreateTopicPage(session: session, categoryId: categoryId));

/// Konu düzenle (MB-C). Kaydedilince güncel [TopicView] döner (iptalde null).
Future<TopicView?> openEditTopic(BuildContext context, Session session, TopicView topic) =>
    _push<TopicView>(context, 'forum_edit', (_) => EditTopicPage(session: session, topic: topic));

/// Forum araması (MB-D).
Future<void> openForumSearch(BuildContext context, Session session) =>
    _push<void>(context, 'forum_search', (_) => const ForumPlaceholderPage(name: 'forum_search'));

/// Kaydedilen konu/yorumlar (MB-D).
Future<void> openForumSaved(BuildContext context, Session session) =>
    _push<void>(context, 'forum_saved', (_) => const ForumPlaceholderPage(name: 'forum_saved'));

/// Forum faaliyetim: Açtığım Konular, Yorumlarım, Kaydedilenler, Takip Ettiklerim (MB-D).
Future<void> openMyForumActivity(BuildContext context, Session session) =>
    _push<void>(context, 'forum_activity', (_) => const ForumPlaceholderPage(name: 'forum_activity'));

/// Forum bildirim tercihleri (MB-D).
Future<void> openForumPrefs(BuildContext context, Session session) =>
    _push<void>(context, 'forum_prefs', (_) => const ForumPlaceholderPage(name: 'forum_prefs'));

/// Şikâyet alt sayfası (MB-D). [targetType]: [kForumReportTopic] | [kForumReportComment]. Gönderildiyse true döner.
Future<bool> openReportSheet(BuildContext context, Session session,
        {required String targetType, required int targetId, bool anonymousAuthor = false}) async =>
    (await _push<bool>(context, 'forum_report', (_) => const ForumPlaceholderPage(name: 'forum_report'))) ?? false;
