package edu.bingol.backend.forum.notify;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.forum.notify.ForumNotifyReader.CommentInfo;
import edu.bingol.backend.forum.notify.ForumNotifyReader.TopicInfo;
import edu.bingol.backend.i18n.I18n;
import edu.bingol.backend.i18n.Lang;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.notification.Notification;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.notification.NotificationService;
import edu.bingol.backend.notification.NotificationSubtype;
import edu.bingol.backend.notification.NotificationTemplates;
import edu.bingol.backend.notification.NotificationType;
import edu.bingol.backend.notification.RecipientGuard;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.support.ResourceBundleMessageSource;

/** Forum bildirim karari: alici, tur, dil, kendine yok, tekrar yok, tercih/mute/engel/pasif, anonimlik, birlesme. */
class ForumNotifierTest {

    // kullanicilar: 1 konu sahibi, 2 yorumcu, 3 ust yorum sahibi, 4/5 takipci, 9 baska
    private final NotificationService notifications = mock(NotificationService.class);
    private final NotificationRepository rows = mock(NotificationRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final BlockService blocks = mock(BlockService.class);
    private final RecipientGuard guard = mock(RecipientGuard.class);
    private final ForumNotificationPrefRepository prefRepo = mock(ForumNotificationPrefRepository.class);
    private final FakeForumData data = new FakeForumData();
    private final Clock clock = Clock.fixed(Instant.parse("2026-11-05T10:00:00Z"), ZoneOffset.UTC);
    private ForumNotifier notifier;

    @BeforeEach
    void setUp() {
        ResourceBundleMessageSource ms = new ResourceBundleMessageSource();
        ms.setBasename("i18n/forumn");
        ms.setDefaultEncoding("UTF-8");
        ms.setFallbackToSystemLocale(false);
        I18n i18n = new I18n(ms, users);
        notifier = new ForumNotifier(notifications, rows, i18n, users, blocks, guard,
                new ForumNotificationPrefService(prefRepo), data, data, "https://bukampus.com.tr", clock);
        when(guard.canReceive(anyLong())).thenReturn(true);
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(prefRepo.findByUserIdIn(anyCollection())).thenReturn(List.of());
        when(prefRepo.findById(anyLong())).thenReturn(Optional.empty());
        for (long id : new long[] {1, 2, 3, 4, 5, 9}) {
            user(id, "Kisi" + id, "tr");
        }
        data.categories.put(7L, Map.of(Lang.TR, "Yemekhane", Lang.EN, "Canteen", Lang.AR, "قاعة الطعام"));
        data.topics.put(100L, new TopicInfo(100, 1, false, "Bugun yemek ne", 7, true));
    }

    private User user(long id, String name, String lang) {
        User u = new User();
        u.setId(id);
        u.setDisplayName(name);
        u.setLanguage(lang);
        when(users.findById(id)).thenReturn(Optional.of(u));
        when(users.findLanguage(id)).thenReturn(Optional.of(lang));
        return u;
    }

    private void comment(long id, long topicId, long author, boolean anon, Long parentId, Long parentAuthor, String body) {
        data.comments.put(id, new CommentInfo(id, topicId, author, anon, parentId, parentAuthor, body, true));
    }

    private void pref(long userId, java.util.function.Consumer<ForumNotificationPref> c) {
        ForumNotificationPref p = ForumNotificationPref.defaults(userId);
        c.accept(p);
        when(prefRepo.findByUserIdIn(anyCollection())).thenAnswer(inv -> {
            java.util.Collection<Long> ids = inv.getArgument(0);
            return ids.contains(userId) ? List.of(p) : List.of();
        });
    }

    @SuppressWarnings("unchecked")
    private ArgumentCaptor<Map<String, String>> captor() {
        return ArgumentCaptor.forClass(Map.class);
    }

    // ------------------------------------------------------------------ konu begenisi

    @Test
    void topicLikeGoesToOwnerInHisLanguageWithoutIdentityLeaks() {
        data.topicsWithImage.add(100L);
        notifier.topicLiked(100, 2);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_LIKE),
                eq("fotl:100:" + clock.instant().getEpochSecond() / 600), eq("Konun beğenildi"),
                eq("Kisi2, “Bugun yemek ne” konunu beğendi"), d.capture());
        Map<String, String> m = d.getValue();
        assertEquals("FORUM_TOPIC", m.get("target"));
        assertEquals("100", m.get("value"));
        assertEquals("100", m.get("topicId"));
        assertEquals("FORUM_TOPIC_LIKE", m.get("forumKind"));
        assertEquals("Yemekhane", m.get("sourceName"));
        assertEquals("Kisi2", m.get("senderName"));
        assertEquals("https://bukampus.com.tr/s/f/100/img", m.get("imageUrl"));
        // kimlik / avatar ASLA
        assertFalse(m.containsKey("userId"));
        assertFalse(m.containsKey("actorId"));
        assertFalse(m.containsKey("senderAvatarUrl"));
    }

    @Test
    void englishAndArabicRecipientsGetTheirLanguage() {
        user(1, "Owner", "en");
        notifier.topicLiked(100, 2);
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_LIKE), anyString(),
                eq("Your topic was liked"), eq("Kisi2 liked your topic “Bugun yemek ne”"), anyMap());

        user(1, "Sahip", "ar");
        data.seen.clear();
        notifier.topicLiked(100, 2);
        ArgumentCaptor<Map<String, String>> d = captor();
        ArgumentCaptor<String> title = ArgumentCaptor.forClass(String.class);
        verify(notifications, times(2)).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_LIKE),
                anyString(), title.capture(), anyString(), d.capture());
        assertEquals("أُعجب أحدهم بموضوعك", title.getAllValues().get(1));
        assertEquals("قاعة الطعام", d.getAllValues().get(1).get("sourceName"));
    }

    @Test
    void selfLikeAndDuplicateLikeAreSilent() {
        notifier.topicLiked(100, 1);
        notifier.topicLiked(100, 2);
        notifier.topicLiked(100, 2); // al-ver-al: ikinci kez gitmez
        verify(notifications, times(1)).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
    }

    @Test
    void likePrefAllOffTopicOffBlockMuteInactiveAreRespected() {
        pref(1, p -> p.setLikes(false));
        notifier.topicLiked(100, 2);
        pref(1, p -> p.setAllEnabled(false));
        notifier.topicLiked(100, 3);
        pref(1, p -> { });
        data.topicOff.add("100:1");
        notifier.topicLiked(100, 4);
        data.topicOff.clear();
        when(blocks.isBlocked(5L, 1L)).thenReturn(true);
        notifier.topicLiked(100, 5);
        data.mutes.add("1:9");
        notifier.topicLiked(100, 9);
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any(), any(), anyMap());

        when(guard.canReceive(1L)).thenReturn(false); // pasif / silinmis alici
        data.mutes.clear();
        when(blocks.isBlocked(5L, 1L)).thenReturn(false);
        data.seen.clear();
        notifier.topicLiked(100, 2);
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
    }

    @Test
    void removedOrHiddenTopicSendsNothing() {
        data.topics.put(100L, new TopicInfo(100, 1, false, "x", 7, false));
        notifier.topicLiked(100, 2);
        notifier.topicLiked(555, 2); // olmayan
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
    }

    @Test
    void sameWindowLikeGroupsIntoOneRowWithOthersCount() {
        Notification existing = new Notification();
        existing.setGroupCount(2);
        when(rows.findFirstByUserIdAndCollapseKeyAndReadAtIsNullOrderByIdDesc(eq(1L), anyString()))
                .thenReturn(Optional.of(existing));
        notifier.topicLiked(100, 2);
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_LIKE), anyString(),
                eq("Konun beğenildi"), eq("Kisi2 ve 2 kişi “Bugun yemek ne” konunu beğendi"), anyMap());
    }

    // ------------------------------------------------------------------ yorum begenisi

    @Test
    void commentLikeGoesToCommentAuthor() {
        comment(500, 100, 3, false, null, null, "merhaba");
        notifier.commentLiked(500, 2);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(3L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_COMMENT_LIKE),
                anyString(), eq("Yorumun beğenildi"), eq("Kisi2 yorumunu beğendi"), d.capture());
        assertEquals("FORUM_COMMENT", d.getValue().get("target"));
        assertEquals("500", d.getValue().get("value"));
        assertEquals("100", d.getValue().get("topicId"));
    }

    @Test
    void anonymousTopicAuthorLikingAComment_isShownByAlias() {
        data.topics.put(100L, new TopicInfo(100, 1, true, "Gizli konu", 7, true));
        data.aliases.put("100:1", 1);
        comment(500, 100, 3, false, null, null, "yorum");
        notifier.commentLiked(500, 1);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(3L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_COMMENT_LIKE),
                anyString(), anyString(), eq("Anonim #1 yorumunu beğendi"), d.capture());
        assertEquals("Anonim #1", d.getValue().get("senderName"));
        assertFalse(d.getValue().values().stream().anyMatch(v -> v.contains("Kisi1")));
    }

    // ------------------------------------------------------------------ yorum olusturma

    @Test
    void commentOnTopicNotifiesOwnerOnlyAndTopicTitleIsInTitle() {
        comment(500, 100, 2, false, null, null, "cok iyi\n  yemek");
        notifier.commentCreated(500, 2);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_COMMENT),
                eq("fotc:100:" + clock.instant().getEpochSecond() / 600), eq("“Bugun yemek ne” konusuna yeni yorum"),
                eq("Kisi2: cok iyi yemek"), d.capture());
        assertEquals("500", d.getValue().get("value"));
        assertEquals("500", d.getValue().get("commentId"));
        assertEquals("FORUM_COMMENT", d.getValue().get("target"));
        verify(notifications, times(1)).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
    }

    @Test
    void replyNotifiesParentAuthorAndOwnerSeparatelyButOwnerParentGetsOnlyReply() {
        comment(400, 100, 3, false, null, null, "ust");
        comment(500, 100, 2, false, 400L, 3L, "yanit");
        notifier.commentCreated(500, 2);
        verify(notifications).send(eq(3L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_COMMENT_REPLY),
                eq("focr:400:" + clock.instant().getEpochSecond() / 600), eq("Yorumuna yanıt var"), eq("Kisi2: yanit"),
                anyMap());
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_COMMENT),
                anyString(), anyString(), anyString(), anyMap());

        // konu sahibi ayni zamanda ust yorum sahibi: yalniz YANIT, ikinci bildirim yok
        org.mockito.Mockito.clearInvocations(notifications);
        comment(401, 100, 1, false, null, null, "sahip yorumu");
        comment(501, 100, 2, false, 401L, 1L, "sahibe yanit");
        notifier.commentCreated(501, 2);
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_COMMENT_REPLY),
                anyString(), anyString(), anyString(), anyMap());
        verify(notifications, times(1)).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
    }

    @Test
    void anonymousCommentIsNamedByAliasAndNeverByRealName() {
        data.aliases.put("100:2", 7);
        comment(500, 100, 2, true, null, null, "gizli yorum");
        notifier.commentCreated(500, 2);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(1L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_TOPIC_COMMENT),
                anyString(), anyString(), eq("Anonim #7: gizli yorum"), d.capture());
        assertEquals("Anonim #7", d.getValue().get("senderName"));
        assertFalse(d.getValue().containsKey("senderAvatarUrl"));
        assertFalse(d.getValue().containsKey("userId"));
        assertFalse(d.getValue().values().stream().anyMatch(v -> v.contains("Kisi2")));
    }

    @Test
    void anonymousAliasMissingFallsBackToPlainAnonymWithoutNumber() {
        comment(500, 100, 2, true, null, null, "gizli yorum");
        notifier.commentCreated(500, 2);
        verify(notifications).send(eq(1L), any(), any(), anyString(), anyString(), eq("Anonim: gizli yorum"), anyMap());
    }

    @Test
    void ownerOfAnonymousTopicCommentingByNameIsStillShownByAliasToOthers() {
        data.topics.put(100L, new TopicInfo(100, 1, true, "Gizli konu", 7, true));
        data.aliases.put("100:1", 1);
        comment(400, 100, 3, false, null, null, "ust");
        comment(500, 100, 1, false, 400L, 3L, "ben yazdim");
        notifier.commentCreated(500, 1);
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(3L), eq(NotificationType.FORUM), eq(NotificationSubtype.FORUM_COMMENT_REPLY),
                anyString(), anyString(), eq("Anonim #1: ben yazdim"), d.capture());
        assertEquals("Anonim #1", d.getValue().get("senderName"));
    }

    @Test
    void replyToOwnCommentDoesNotNotifyAndDuplicateEventIsIgnored() {
        comment(400, 100, 2, false, null, null, "ust");
        comment(500, 100, 2, false, 400L, 2L, "kendime");
        notifier.commentCreated(500, 2); // yalniz konu sahibi (1) bildirim alir
        notifier.commentCreated(500, 2); // tekrar gelen olay: bildirim yok
        verify(notifications, times(1)).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
        verify(notifications).send(eq(1L), any(), eq(NotificationSubtype.FORUM_TOPIC_COMMENT), any(), any(), any(), anyMap());
    }

    @Test
    void followersGetBulkNotificationPerLanguageExcludingActorOwnerParentBlockedMutedAndOptedOut() {
        user(4, "F4", "en");
        user(5, "F5", "tr");
        user(6, "F6", "tr");
        user(7, "F7", "tr");
        user(8, "F8", "tr");
        data.followers.put(100L, Set.of(1L, 2L, 3L, 4L, 5L, 6L, 7L, 8L));
        org.mockito.Mockito.doAnswer(inv -> {
            java.util.List<User> out = new java.util.ArrayList<>();
            for (Long uid : (Iterable<Long>) inv.getArgument(0)) {
                out.add(users.findById(uid).orElseThrow());
            }
            return out;
        }).when(users).findAllById(any());
        when(blocks.hiddenFrom(2L)).thenReturn(Set.of(6L)); // 6 engelli
        data.mutes.add("7:2"); // 7 yazari sessize almis
        pref(8, p -> p.setFollowedTopics(false)); // 8 takip bildirimini kapatmis
        comment(400, 100, 3, false, null, null, "ust");
        comment(500, 100, 2, false, 400L, 3L, "yanit");

        notifier.commentCreated(500, 2);

        ArgumentCaptor<List<Long>> ids = ArgumentCaptor.forClass(List.class);
        ArgumentCaptor<NotificationTemplates.Template> tpl = ArgumentCaptor.forClass(NotificationTemplates.Template.class);
        verify(notifications, times(2)).sendTemplatedBulkBy(ids.capture(), tpl.capture(), anyMap(), any(), any(String[].class));
        assertEquals(NotificationType.FORUM, tpl.getValue().type());
        assertEquals(NotificationSubtype.FORUM_FOLLOWED_TOPIC_COMMENT, tpl.getValue().subtype());
        List<Long> all = ids.getAllValues().stream().flatMap(List::stream).sorted().toList();
        assertEquals(List.of(4L, 5L), all);
    }

    @Test
    void removedCommentOrTopicSendsNothing() {
        data.comments.put(500L, new CommentInfo(500, 100, 2, false, null, null, "x", false));
        notifier.commentCreated(500, 2);
        notifier.commentLiked(500, 3);
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
        verify(notifications, never()).sendTemplatedBulkBy(any(), any(), anyMap(), any(), any(String[].class));
    }

    @Test
    void errorsNeverEscape() {
        data.topics.put(100L, null);
        comment(500, 100, 2, false, null, null, "x");
        when(users.findById(anyLong())).thenThrow(new IllegalStateException("db"));
        notifier.commentCreated(500, 2);
        notifier.topicLiked(100, 2);
        notifier.moderated(false, 100, "REMOVE", null);
    }

    // ------------------------------------------------------------------ moderasyon

    @Test
    void moderationGoesToOwnerAsSystemWithReasonAndCannotBeSilencedByPrefs() {
        pref(1, p -> p.setAllEnabled(false)); // tercihle susturulamaz
        notifier.moderated(false, 100, "REMOVE", "Kural 3: spam");
        ArgumentCaptor<Map<String, String>> d = captor();
        verify(notifications).send(eq(1L), eq(NotificationType.SYSTEM), isNull(),
                eq("fomod:t100:REMOVE"), eq("Konun kaldırıldı"),
                eq("“Bugun yemek ne” başlıklı konun kaldırıldı. Gerekçe: Kural 3: spam"), d.capture());
        Map<String, String> m = d.getValue();
        assertEquals("1", m.get("moderation"));
        assertEquals("FORUM_MODERATION", m.get("forumKind"));
        assertEquals("FORUM_TOPIC", m.get("target"));
        assertEquals("REMOVE", m.get("action"));
        assertEquals("Yemekhane", m.get("sourceName"));
    }

    @Test
    void moderationOnCommentUnknownActionAndInactiveOwner() {
        comment(500, 100, 3, false, null, null, "kotu yorum");
        notifier.moderated(true, 500, "REMOVE", null);
        verify(notifications).send(eq(3L), eq(NotificationType.SYSTEM), isNull(), eq("fomod:c500:REMOVE"),
                eq("Yorumun kaldırıldı"), eq("“kotu yorum” yorumun topluluk kuralları nedeniyle kaldırıldı."), anyMap());

        notifier.moderated(false, 100, "WARN", null);
        verify(notifications).send(eq(1L), eq(NotificationType.SYSTEM), isNull(), eq("fomod:t100:WARN"),
                eq("Forum içeriğin için moderatör işlemi"), anyString(), anyMap());

        org.mockito.Mockito.clearInvocations(notifications);
        when(guard.canReceive(1L)).thenReturn(false);
        notifier.moderated(false, 100, "LOCK", null);
        verify(notifications, never()).send(anyLong(), any(), any(), any(), any(), any(), anyMap());
        assertTrue(true);
    }
}
