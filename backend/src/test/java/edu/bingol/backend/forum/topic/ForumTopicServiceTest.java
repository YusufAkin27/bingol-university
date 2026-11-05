package edu.bingol.backend.forum.topic;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.forum.category.ForumCategory;
import edu.bingol.backend.forum.category.ForumCategoryRepository;
import edu.bingol.backend.forum.poll.spi.CreatePollRequest;
import edu.bingol.backend.forum.poll.spi.ForumPollService;
import edu.bingol.backend.forum.poll.spi.PollView;
import edu.bingol.backend.forum.topic.ForumTopicDtos.CreateTopicRequest;
import edu.bingol.backend.forum.topic.ForumTopicDtos.UpdateTopicRequest;
import edu.bingol.backend.forum.topic.dto.TopicView;
import edu.bingol.backend.forum.topic.spi.ForumAuthorResolver;
import edu.bingol.backend.forum.topic.spi.ForumMuteLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicLookup;
import edu.bingol.backend.forum.topic.spi.ForumTopicStateService;
import edu.bingol.backend.forum.topic.spi.TopicRef;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

/** Konu servisi: olustur/duzenle/sil/sahiplik, dogrulama, idempotency, anonim maskeleme, gorunurluk, durum SPI'lari (H2). */
@SpringBootTest
@org.springframework.test.context.TestPropertySource(properties = "spring.messages.basename=i18n/messages,i18n/forum")
class ForumTopicServiceTest {

    @MockitoBean edu.bingol.backend.common.RateLimiter limiter;
    @MockitoBean ForumMuteLookup mutes;
    // C birlesti: ForumPollVoteService somut ForumPollServiceImpl ister; saf mock tipi bozar -> casus (gercek bean sarilir)
    @org.springframework.test.context.bean.override.mockito.MockitoSpyBean ForumPollService polls;

    @Autowired ForumTopicService service;
    @Autowired ForumTopicRepository topics;
    @Autowired ForumCategoryRepository cats;
    @Autowired UserRepository users;
    @Autowired ForumTopicLookup lookup;
    @Autowired ForumTopicStateService state;
    @Autowired ForumAuthorResolver authors;
    @Autowired ForumAnonAliasService aliases;
    @Autowired BlockService blocks;

    @org.junit.jupiter.api.BeforeEach
    void tr() {
        org.springframework.context.i18n.LocaleContextHolder.setLocale(java.util.Locale.forLanguageTag("tr"));
    }

    private User u(String n) {
        return ForumTestSupport.user(users, n);
    }

    private ForumCategory cat() {
        return ForumTestSupport.category(cats, "Kat");
    }

    private static CreateTopicRequest req(String title, String body, Long cat, boolean anon) {
        return new CreateTopicRequest(title, body, cat, anon, List.of(), null);
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    @Test
    void createEditDeleteWithOwnershipRules() {
        User me = u("ben");
        User other = u("diger");
        ForumCategory c = cat();
        TopicView v = service.create(me.getId(), req("  Merhaba   <b>dunya</b>​ ", "Ilk satir\r\n\r\n\r\n\r\nIkinci <script>alert(1)</script>", c.getId(), false), null);
        assertEquals("Merhaba dunya", v.title(), "HTML etiketi, sifir genislik ve cift bosluk temizlenir");
        assertEquals("Ilk satir\n\nIkinci alert(1)", v.body());
        assertTrue(v.mine() && v.canEdit() && v.canDelete());
        assertFalse(v.author().anonymous());
        assertEquals(me.getId(), v.author().userId());
        assertNull(v.editedAt());

        TopicView seenByOther = service.get(other.getId(), v.id());
        assertFalse(seenByOther.mine() || seenByOther.canEdit() || seenByOther.canDelete());

        assertEquals("FORUM_NOT_OWNER", code(() -> service.update(other.getId(), v.id(), new UpdateTopicRequest("x", null, null))));
        assertEquals("FORUM_NOT_OWNER", code(() -> service.delete(other.getId(), v.id())));

        TopicView edited = service.update(me.getId(), v.id(), new UpdateTopicRequest("Yeni baslik", null, null));
        assertEquals("Yeni baslik", edited.title());
        assertEquals(v.body(), edited.body(), "null alan degismez");
        assertNotNull(edited.editedAt());

        service.delete(me.getId(), v.id());
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.get(me.getId(), v.id())));
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.get(other.getId(), v.id())));
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.delete(me.getId(), v.id())), "eszamanli/ikinci silme acikca 404");
        assertTrue(lookup.topic(v.id()).isEmpty());
        assertNotNull(topics.findById(v.id()).orElseThrow().getDeletedAt(), "yumusak silme");
    }

    @Test
    void validation() {
        User me = u("ben");
        ForumCategory c = cat();
        assertEquals("FORUM_TITLE_REQUIRED", code(() -> service.create(me.getId(), req("   ", "govde", c.getId(), false), null)));
        assertEquals("FORUM_TITLE_REQUIRED", code(() -> service.create(me.getId(), req("<i></i>", "govde", c.getId(), false), null)));
        assertEquals("FORUM_BODY_REQUIRED", code(() -> service.create(me.getId(), req("Baslik", " \n ", c.getId(), false), null)));
        assertEquals("FORUM_TITLE_TOO_LONG", code(() -> service.create(me.getId(), req("a".repeat(151), "govde", c.getId(), false), null)));
        service.create(me.getId(), req("a".repeat(150), "b".repeat(10_000), c.getId(), false), null);
        assertEquals("FORUM_BODY_TOO_LONG", code(() -> service.create(me.getId(), req("Baslik", "b".repeat(10_001), c.getId(), false), null)));
        assertEquals("FORUM_CATEGORY_NOT_FOUND", code(() -> service.create(me.getId(), req("Baslik", "govde", 987654L, false), null)));
        assertEquals("FORUM_CATEGORY_NOT_FOUND", code(() -> service.create(me.getId(), req("Baslik", "govde", null, false), null)));
        assertEquals("FORUM_TOO_MANY_IMAGES", code(() -> service.create(me.getId(),
                new CreateTopicRequest("Baslik", "govde", c.getId(), false, List.of(1L, 2L, 3L, 4L, 5L), null), null)));
        ForumCategory archived = cat();
        archived.setActive(false);
        cats.save(archived);
        assertEquals("FORUM_CATEGORY_ARCHIVED", code(() -> service.create(me.getId(), req("Baslik", "govde", archived.getId(), false), null)));
    }

    @Test
    void idempotencyKeyReturnsSameTopic() {
        User me = u("ben");
        ForumCategory c = cat();
        String key = "key-" + java.util.UUID.randomUUID();
        TopicView a = service.create(me.getId(), req("Tek", "govde", c.getId(), false), key);
        TopicView b = service.create(me.getId(), req("Tek", "govde", c.getId(), false), key);
        assertEquals(a.id(), b.id());
        assertEquals(1, topics.findAll(org.springframework.data.domain.PageRequest.of(0, 1000)).stream()
                .filter(t -> t.getUserId().equals(me.getId())).count());
        // farkli anahtar + AYNI metin: D'nin tekrar-icerik engeli (429); farkli metin yeni konu olur
        assertEquals("FORUM_DUPLICATE_CONTENT", code(() -> service.create(me.getId(), req("Tek", "govde", c.getId(), false), "other-" + key)));
        TopicView c2 = service.create(me.getId(), req("Tek iki", "govde", c.getId(), false), "other-" + key);
        assertNotEquals(a.id(), c2.id());
    }

    @Test
    void concurrentSameIdempotencyKeyCreatesOneTopic() throws Exception {
        User me = u("ben");
        ForumCategory c = cat();
        String key = "race-" + java.util.UUID.randomUUID();
        ExecutorService pool = Executors.newFixedThreadPool(6);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Long>> fs = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            fs.add(pool.submit(() -> {
                go.await();
                try {
                    return service.create(me.getId(), req("Yaris", "govde", c.getId(), false), key).id();
                } catch (RuntimeException e) {
                    return -1L; // kaybeden yaris: kimse ikinci konu acmamali
                }
            }));
        }
        go.countDown();
        Set<Long> ids = new HashSet<>();
        for (Future<Long> f : fs) {
            ids.add(f.get());
        }
        pool.shutdown();
        ids.remove(-1L);
        assertEquals(1, ids.size(), "ayni anahtar tek konu");
        long n = topics.findAll(org.springframework.data.domain.PageRequest.of(0, 1000)).stream()
                .filter(t -> t.getUserId().equals(me.getId())).count();
        assertEquals(1, n);
    }

    @Test
    void lockedTopicRejectsEditsAndStateTransitionsAreIdempotent() {
        User me = u("ben");
        ForumCategory c = cat();
        TopicView v = service.create(me.getId(), req("Kilit", "govde", c.getId(), false), null);
        TopicRef r = state.lock(v.id());
        assertTrue(r.locked());
        state.lock(v.id());
        assertEquals("FORUM_TOPIC_LOCKED", code(() -> service.update(me.getId(), v.id(), new UpdateTopicRequest("x", null, null))));
        assertTrue(service.get(me.getId(), v.id()).locked());
        assertFalse(service.get(me.getId(), v.id()).canEdit());
        assertFalse(state.unlock(v.id()).locked());
        state.unlock(v.id());
        service.update(me.getId(), v.id(), new UpdateTopicRequest("x", null, null));

        assertTrue(service.get(me.getId(), v.id()).pinned() == false);
        state.pin(v.id());
        assertTrue(service.get(me.getId(), v.id()).pinned());
        state.unpin(v.id());
        assertFalse(service.get(me.getId(), v.id()).pinned());

        TopicRef removed = state.remove(v.id(), "spam");
        assertEquals(TopicRef.Status.REMOVED, removed.status());
        assertTrue(lookup.visibleTopic(v.id(), me.getId()).isEmpty(), "kaldirilmis konu kimseye gorunmez");
        assertEquals(TopicRef.Status.REMOVED, lookup.topic(v.id()).orElseThrow().status());
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.get(me.getId(), v.id())));
        assertEquals(TopicRef.Status.ACTIVE, state.restore(v.id()).status());
        assertTrue(lookup.visibleTopic(v.id(), me.getId()).isPresent());
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> state.pin(99999999L)));
    }

    @Test
    void anonymousTopicNeverLeaksIdentity() {
        User me = u("GizliAd");
        User other = u("diger");
        ForumCategory c = cat();
        TopicView mineView = service.create(me.getId(), req("Anonim konu", "govde", c.getId(), true), null);
        assertTrue(mineView.mine(), "yazar kendi anonim konusunu mine:true gorur");
        assertTrue(mineView.author().anonymous());
        assertEquals("Anonim #1", mineView.author().displayName());

        TopicView v = service.get(other.getId(), mineView.id());
        assertFalse(v.mine());
        assertNull(v.author().userId());
        assertNull(v.author().avatarUrl());
        assertNull(v.author().department());
        assertTrue(v.author().anonymous());
        assertEquals("Anonim #1", v.author().displayName());
        String dump = v.toString();
        assertFalse(dump.contains("GizliAd"), dump);
        assertFalse(dump.contains("userId=" + me.getId()), dump);
        assertFalse(dump.contains(me.getEmail()));

        // Takma ad (konu, kullanici) basina kararli; ikinci kullanici #2
        assertEquals("Anonim #1", authors.resolve(other.getId(), new ForumAuthorResolver.Key(mineView.id(), me.getId(), true)).displayName());
        assertEquals("Anonim #2", authors.resolve(me.getId(), new ForumAuthorResolver.Key(mineView.id(), other.getId(), true)).displayName());
        assertEquals("Anonim #2", authors.resolve(me.getId(), new ForumAuthorResolver.Key(mineView.id(), other.getId(), true)).displayName());
        // Anonim olmayan gorunum kimligi tasir; ayni konuda anonim secimi AYRIDIR
        assertEquals(other.getId(), authors.resolve(me.getId(), new ForumAuthorResolver.Key(mineView.id(), other.getId(), false)).userId());
    }

    @Test
    void anonAliasAllocationIsAtomicUnderRace() throws Exception {
        User owner = u("sahip");
        ForumCategory c = cat();
        ForumTopic t = ForumTestSupport.topic(topics, owner.getId(), c.getId(), "yaris", 0, 0, true, 1);
        int n = 8;
        List<User> list = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            list.add(u("k" + i));
        }
        ExecutorService pool = Executors.newFixedThreadPool(n);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Integer>> fs = new ArrayList<>();
        for (User x : list) {
            fs.add(pool.submit(() -> {
                go.await();
                return aliases.aliasFor(t.getId(), x.getId());
            }));
        }
        go.countDown();
        Set<Integer> seen = new HashSet<>();
        for (Future<Integer> f : fs) {
            seen.add(f.get());
        }
        pool.shutdown();
        assertEquals(n, seen.size(), "her kullanici farkli numara alir");
        for (int i = 1; i <= n; i++) {
            assertTrue(seen.contains(i), "numaralar 1.." + n + " atlamasiz: " + seen);
        }
        // ayni kullanici ikinci kez ayni numarayi alir
        User first = list.get(0);
        assertEquals(aliases.aliasFor(t.getId(), first.getId()), aliases.aliasFor(t.getId(), first.getId()));
    }

    @Test
    void blockAndMuteHideTopicEverywhereForTheViewer() {
        User author = u("yazar");
        User viewer = u("bakan");
        User muter = u("susturan");
        ForumCategory c = cat();
        TopicView anon = service.create(author.getId(), req("Gizli", "govde", c.getId(), true), null);
        assertTrue(lookup.visibleTopic(anon.id(), viewer.getId()).isPresent());

        when(mutes.mutedBy(muter.getId())).thenReturn(Set.of(author.getId()));
        // karar: sessize alma anonim icerikte UYGULANMAZ (kimlik sinanamasin); acik (anonim olmayan) icerikte uygulanir
        assertTrue(lookup.visibleTopic(anon.id(), muter.getId()).isPresent(), "sessize alinan ANONIM icerik gizlenmez");
        assertEquals(anon.id(), service.get(muter.getId(), anon.id()).id());
        TopicView named = service.create(author.getId(), req("Acik", "acik govde", c.getId(), false), null);
        assertTrue(lookup.visibleTopic(named.id(), muter.getId()).isEmpty(), "sessize alinan ACIK icerik gizlenir");
        assertEquals("FORUM_TOPIC_NOT_FOUND", code(() -> service.get(muter.getId(), named.id())));

        blocks.block(viewer.getId(), author.getId());
        assertTrue(lookup.visibleTopic(anon.id(), viewer.getId()).isEmpty(), "engel (bakan engelledi)");
        assertTrue(lookup.visibleTopic(anon.id(), author.getId()).isPresent(), "yazar kendi konusunu gorur");
        User blockedMe = u("engelleyen");
        blocks.block(author.getId(), blockedMe.getId());
        assertTrue(lookup.visibleTopic(anon.id(), blockedMe.getId()).isEmpty(), "engel iki yonludur");
    }

    @Test
    void suspendedAuthorsTopicIsInvisibleToOthers() {
        User author = u("yazar");
        User viewer = u("bakan");
        ForumCategory c = cat();
        TopicView v = service.create(author.getId(), req("Konu", "govde", c.getId(), false), null);
        author.setStatus(edu.bingol.backend.user.UserStatus.SUSPENDED);
        users.save(author);
        assertTrue(lookup.visibleTopic(v.id(), viewer.getId()).isEmpty());
        assertTrue(lookup.visibleTopic(v.id(), author.getId()).isPresent());
    }

    @Test
    void pollIsCreatedInsideTheSameTransactionAndFailureRollsTheTopicBack() {
        User me = u("ben");
        ForumCategory c = cat();
        CreatePollRequest poll = new CreatePollRequest("Soru", List.of("a", "b"), null, false);
        PollView pv = new PollView(1L, "Soru", List.of(), 0, null, null, false, false, true);
        org.mockito.Mockito.doReturn(pv).when(polls).pollFor(any(), any());
        TopicView ok = service.create(me.getId(), new CreateTopicRequest("Anketli", "govde", c.getId(), false, List.of(), poll), null);
        verify(polls).createForTopic(ok.id(), poll);
        assertTrue(ok.hasPoll());
        assertNotNull(ok.poll());

        org.mockito.Mockito.doThrow(new ApiException(org.springframework.http.HttpStatus.BAD_REQUEST, "FORUM_POLL_INVALID", "x"))
                .when(polls).createForTopic(any(), any());
        long before = topics.findAll(org.springframework.data.domain.PageRequest.of(0, 1000)).stream()
                .filter(t -> t.getUserId().equals(me.getId())).count();
        assertEquals("FORUM_POLL_INVALID", code(() -> service.create(me.getId(), new CreateTopicRequest("Bozuk", "govde", c.getId(), false, List.of(), poll), null)));
        long after = topics.findAll(org.springframework.data.domain.PageRequest.of(0, 1000)).stream()
                .filter(t -> t.getUserId().equals(me.getId())).count();
        assertEquals(before, after, "anket hatasi konuyu da geri alir");
    }
}
