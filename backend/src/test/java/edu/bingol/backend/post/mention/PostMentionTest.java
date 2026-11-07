package edu.bingol.backend.post.mention;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.moderation.UserBlock;
import edu.bingol.backend.moderation.UserBlockRepository;
import edu.bingol.backend.notification.NotificationRepository;
import edu.bingol.backend.post.PostDtos.CreatePostRequest;
import edu.bingol.backend.post.PostDtos.MentionView;
import edu.bingol.backend.post.PostDtos.PostView;
import edu.bingol.backend.post.PostService;
import edu.bingol.backend.post.follow.UserFollow;
import edu.bingol.backend.post.follow.UserFollowRepository;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/** Gonderi etiketleme (V1310): dogrulama, gorunum suzgeci, duzenleme ve bildirim kurallari. */
@SpringBootTest
class PostMentionTest {

    @Autowired PostService service;
    @Autowired UserRepository users;
    @Autowired UserFollowRepository follows;
    @Autowired UserBlockRepository blocks;
    @Autowired PostMediaRepository mediaRepo;
    @Autowired NotificationRepository notifications;
    @Autowired JdbcTemplate jdbc;

    private User newUser(String name) {
        User u = new User();
        u.setEmail("m" + UUID.randomUUID().toString().substring(0, 8) + "@bingol.edu.tr");
        u.setPasswordHash("x");
        u.setDisplayName(name);
        u.setEmailVerified(true);
        return users.saveAndFlush(u);
    }

    /** a, b'yi takip eder (kabul edilmis takip). */
    private void follow(User a, User b) {
        follows.saveAndFlush(new UserFollow(a.getId(), b.getId()));
    }

    private Long photo(User owner) {
        return PostFixtures0.media(mediaRepo, owner.getId());
    }

    private PostView create(User author, String text, List<Long> mentions) {
        return service.create(author.getId(), new CreatePostRequest(text, List.of(photo(author)), mentions));
    }

    private static String code(Runnable r) {
        return assertThrows(ApiException.class, r::run).code();
    }

    private boolean notified(User target, Long postId) {
        return notifications.existsByUserIdAndCollapseKey(target.getId(), "postmention:" + postId);
    }

    @Test
    void mentionsFollowedUserAndNotifiesOnce() {
        User a = newUser("Ayse Yilmaz");
        User b = newUser("Burak Kaya");
        follow(a, b);

        PostView v = create(a, "Harika bir aksam @Burak Kaya ile", List.of(b.getId()));

        assertEquals("Harika bir aksam @Burak Kaya ile", v.text(), "metne dokunulmaz");
        assertEquals(List.of(new MentionView(b.getId(), "Burak Kaya")), v.mentions());
        assertTrue(notified(b, v.id()), "etiketlenene bildirim");
        assertFalse(notified(a, v.id()));
        // get de etiketi tasir
        assertEquals(1, service.get(b.getId(), v.id()).mentions().size());
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM post_mention WHERE post_id = ?", Integer.class, v.id()));
    }

    @Test
    void mentionRequiresFollowingActiveNoBlockNoSelf() {
        User a = newUser("A Yazar");
        User notFollowed = newUser("Takipsiz");
        User followedBlocked = newUser("Engelli");
        User followedInactive = newUser("Pasif");
        User ok = newUser("Tamam");
        follow(a, followedBlocked);
        follow(a, followedInactive);
        follow(a, ok);
        // YALNIZ karsi yon takip: etiketleyen takip etmiyor -> gecersiz
        follow(notFollowed, a);

        blocks.saveAndFlush(block(followedBlocked.getId(), a.getId()));
        followedInactive.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(followedInactive);

        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(notFollowed.getId()))));
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(followedBlocked.getId()))));
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(followedInactive.getId()))));
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(a.getId()))), "kendini etiketleyemez");
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(987654321L))));
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(ok.getId(), notFollowed.getId()))),
                "tek gecersiz kimlik tum istegi reddeder");
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", java.util.Arrays.asList(ok.getId(), null))));
        // reddedilen istek hicbir gonderi/etiket/bildirim birakmaz
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM post WHERE author_id = ?", Integer.class, a.getId()));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM post_mention WHERE user_id = ?", Integer.class, ok.getId()));
        // gecerli kimlik kabul edilir
        assertEquals(1, create(a, "tamam", List.of(ok.getId())).mentions().size());
    }

    @Test
    void atMostTenDistinctAndDuplicatesAreCollapsed() {
        User a = newUser("Cok Takipli");
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            User t = newUser("Kisi " + i);
            follow(a, t);
            ids.add(t.getId());
        }
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", ids)), "11 farkli kisi");
        // 10 farkli kisi + tekrarlar: tekillestirilir, kabul
        List<Long> tenWithDupes = new ArrayList<>(ids.subList(0, 10));
        tenWithDupes.addAll(ids.subList(0, 5));
        PostView v = create(a, "x", tenWithDupes);
        assertEquals(10, v.mentions().size());
        assertEquals(10, jdbc.queryForObject("SELECT COUNT(*) FROM post_mention WHERE post_id = ?", Integer.class, v.id()));
        // etiketsiz (alan yok / bos) gonderi
        assertTrue(create(a, "y", null).mentions().isEmpty());
        assertTrue(create(a, "z", List.of()).mentions().isEmpty());
    }

    @Test
    void editRewritesListAndNotifiesOnlyNewlyAdded() {
        User a = newUser("Duzenleyen");
        User b = newUser("Bir");
        User c = newUser("Iki");
        follow(a, b);
        follow(a, c);
        PostView v = create(a, "ilk", List.of(b.getId()));
        assertTrue(notified(b, v.id()));
        assertFalse(notified(c, v.id()));
        long bBefore = notifications.countByUserIdAndReadAtIsNull(b.getId());

        // b kalir, c eklenir: yalniz c'ye bildirim, b'ye ikinci bildirim yok
        PostView e1 = service.update(a.getId(), v.id(), "ilk duzenleme", List.of(b.getId(), c.getId()));
        assertEquals(2, e1.mentions().size());
        assertTrue(notified(c, v.id()));
        assertEquals(bBefore, notifications.countByUserIdAndReadAtIsNull(b.getId()), "mevcut etikete tekrar bildirim yok");

        // b cikarilir
        PostView e2 = service.update(a.getId(), v.id(), "ikinci", List.of(c.getId()));
        assertEquals(List.of(c.getId()), e2.mentions().stream().map(MentionView::userId).toList());

        // b yeniden eklenir: bildirim zaten gitmisti, tekrar gitmez
        long bAfter = notifications.countByUserIdAndReadAtIsNull(b.getId());
        service.update(a.getId(), v.id(), "ucuncu", List.of(b.getId(), c.getId()));
        assertEquals(bAfter, notifications.countByUserIdAndReadAtIsNull(b.getId()));

        // alan YOK (eski istemci): etiketler degismez
        PostView e3 = service.update(a.getId(), v.id(), "dorduncu");
        assertEquals(2, e3.mentions().size());
        assertEquals("dorduncu", e3.text());

        // bos liste: hepsi kalkar
        assertTrue(service.update(a.getId(), v.id(), "besinci", List.of()).mentions().isEmpty());
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM post_mention WHERE post_id = ?", Integer.class, v.id()));

        // takipten cikilmis eski etiket yeniden gonderilince duzenleme bozulmaz; yeni takipsiz kisi reddedilir
        service.update(a.getId(), v.id(), "altinci", List.of(b.getId()));
        follows.deleteById(new edu.bingol.backend.post.social.PairId(a.getId(), b.getId()));
        assertEquals(1, service.update(a.getId(), v.id(), "yedinci", List.of(b.getId())).mentions().size());
        User d = newUser("Takipsiz");
        assertEquals("POST_MENTION_INVALID", code(() -> service.update(a.getId(), v.id(), "x", List.of(b.getId(), d.getId()))));
    }

    @Test
    void viewFiltersBlockedAndInactiveForViewerOnly() {
        User a = newUser("Yazar");
        User b = newUser("Gorunur");
        User c = newUser("Sonradan Engelli");
        User d = newUser("Sonradan Pasif");
        User viewer = newUser("Bakan");
        follow(a, b);
        follow(a, c);
        follow(a, d);
        PostView v = create(a, "etiketli", List.of(b.getId(), c.getId(), d.getId()));
        assertEquals(3, v.mentions().size());

        // bakan c'yi engeller: yalniz bakanin listesinden c duser (yazarin ve baskalarinin listesinde kalir)
        blocks.saveAndFlush(block(viewer.getId(), c.getId()));
        d.setStatus(UserStatus.SUSPENDED);
        users.saveAndFlush(d);

        List<Long> forViewer = service.get(viewer.getId(), v.id()).mentions().stream().map(MentionView::userId).toList();
        assertEquals(List.of(b.getId()), forViewer);
        List<Long> forAuthor = service.get(a.getId(), v.id()).mentions().stream().map(MentionView::userId).toList();
        assertEquals(List.of(b.getId(), c.getId()), forAuthor, "pasif hesap herkesten gizli, engelli yalniz bakandan");
    }

    @Test
    void mentionedUserWhoBlockedAuthorNoLongerGetsNotification() {
        User a = newUser("Yazar2");
        User b = newUser("Engelleyen");
        follow(a, b);
        // b, a'yi engelledi: etiket kurulamaz (karsilikli engel iliskisi)
        blocks.saveAndFlush(block(b.getId(), a.getId()));
        assertEquals("POST_MENTION_INVALID", code(() -> create(a, "x", List.of(b.getId()))));
    }

    private static UserBlock block(Long blocker, Long blocked) {
        return new UserBlock(blocker, blocked);
    }

    /** Test yardimcisi: baglanmamis IMAGE medya. */
    private static final class PostFixtures0 {
        static Long media(PostMediaRepository repo, Long owner) {
            PostMedia m = new PostMedia();
            m.setOwnerId(owner);
            m.setKind(PostMedia.IMAGE);
            m.setStorageKey("t/" + UUID.randomUUID() + ".jpg");
            m.setContentType("image/jpeg");
            m.setBytes(10);
            return repo.saveAndFlush(m).getId();
        }
    }
}
