package edu.bingol.backend.share;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import edu.bingol.backend.common.ApiException;
import edu.bingol.backend.community.Community;
import edu.bingol.backend.community.CommunityMember;
import edu.bingol.backend.community.CommunityMemberRepository;
import edu.bingol.backend.community.CommunityRepository;
import edu.bingol.backend.event.UserEvent;
import edu.bingol.backend.event.UserEventRepository;
import edu.bingol.backend.moderation.BlockService;
import edu.bingol.backend.news.ContentType;
import edu.bingol.backend.news.NewsItem;
import edu.bingol.backend.news.NewsRepository;
import edu.bingol.backend.post.Post;
import edu.bingol.backend.post.PostRepository;
import edu.bingol.backend.post.follow.PrivateAccountGate;
import edu.bingol.backend.post.media.PostMedia;
import edu.bingol.backend.post.media.PostMediaRepository;
import edu.bingol.backend.user.User;
import edu.bingol.backend.user.UserRepository;
import edu.bingol.backend.user.UserStatus;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Paylasilan icerigin gorunurluk karari: gizli hesap, engel, silinme/gizleme, ozel kulup, haber gizleme, gorsel URL kurali. */
class ShareServiceTest {

    private final NewsRepository news = mock(NewsRepository.class);
    private final PostRepository posts = mock(PostRepository.class);
    private final PostMediaRepository postMedia = mock(PostMediaRepository.class);
    private final UserEventRepository events = mock(UserEventRepository.class);
    private final CommunityRepository communities = mock(CommunityRepository.class);
    private final CommunityMemberRepository members = mock(CommunityMemberRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PrivateAccountGate gate = mock(PrivateAccountGate.class);
    private final BlockService blocks = mock(BlockService.class);
    private final ShareService service = new ShareService(news, posts, postMedia, events, communities, members, users,
            gate, blocks, "https://bukampus.com.tr/");

    private static final long VIEWER = 7L;
    private static final long AUTHOR = 9L;

    @BeforeEach
    void setUp() {
        when(gate.privateAmong(anyCollection())).thenReturn(Set.of());
        when(gate.lockedAmong(anyLong(), anyCollection())).thenReturn(Set.of());
        when(blocks.hiddenFrom(anyLong())).thenReturn(Set.of());
        when(postMedia.findByPostIdIn(anyCollection())).thenReturn(List.of());
    }

    private static NewsItem newsItem(long id, ContentType type, boolean hidden, String image) {
        NewsItem n = new NewsItem();
        n.setId(id);
        n.setType(type);
        n.setTitle("Baslik " + id);
        n.setSummary("Ozet metni");
        n.setImageUrl(image);
        n.setHidden(hidden);
        return n;
    }

    private Post post(long id, long author, String body) {
        Post p = new Post();
        p.setId(id);
        p.setAuthorId(author);
        p.setBody(body);
        when(posts.findAllById(anyCollection())).thenAnswer(inv -> List.of(p));
        User u = new User();
        u.setId(author);
        u.setDisplayName("Ayse Yilmaz");
        u.setStatus(UserStatus.ACTIVE);
        when(users.findAllById(anyCollection())).thenReturn(List.of(u));
        return p;
    }

    private void mockNews(NewsItem... items) {
        when(news.findAllById(anyCollection())).thenReturn(List.of(items));
    }

    // --- baglanti ---

    @Test
    void linkUsesTypeCodeAndTrimsBaseUrl() {
        assertEquals("https://bukampus.com.tr/s/p/12", service.link(new ShareRef(ShareType.POST, 12)));
        assertEquals("https://bukampus.com.tr/s/r/3", service.link(new ShareRef(ShareType.REEL, 3)));
        assertEquals("https://bukampus.com.tr/s/n/4", service.link(new ShareRef(ShareType.NEWS, 4)));
        assertEquals("https://bukampus.com.tr/s/e/5", service.link(new ShareRef(ShareType.EVENT, 5)));
    }

    @Test
    void typeParsingAcceptsNamesAndCodes() {
        assertEquals(ShareType.REEL, ShareType.parse(" reel "));
        assertNull(ShareType.parse("COMMENT"));
        assertEquals(ShareType.EVENT, ShareType.ofCode("e"));
        assertNull(ShareType.ofCode("x"));
    }

    // --- haber / duyuru ---

    @Test
    void visibleNewsAndAnnouncementResolveForAnonymousAndUser() {
        mockNews(newsItem(1, ContentType.DUYURU, false, null));
        ShareRef ref = new ShareRef(ShareType.NEWS, 1);

        ShareService.Resolved anon = service.publicView(ref).orElseThrow();
        ShareCard card = service.cards(VIEWER, List.of(ref)).get(ref);

        assertEquals("DUYURU", anon.kind());
        assertEquals("Baslik 1", anon.title());
        assertTrue(card.available());
        assertEquals("NEWS", card.type());
        assertEquals("https://bukampus.com.tr/s/n/1", card.url());
    }

    @Test
    void hiddenOrMissingNewsIsUnavailableWithoutAnyDetail() {
        mockNews(newsItem(1, ContentType.HABER, true, "https://www.bingol.edu.tr/a.jpg"));
        ShareRef hidden = new ShareRef(ShareType.NEWS, 1);
        ShareRef missing = new ShareRef(ShareType.NEWS, 2);

        assertTrue(service.publicView(hidden).isEmpty());
        ShareCard c = service.cards(VIEWER, List.of(hidden, missing)).get(hidden);
        assertFalse(c.available());
        assertNull(c.title());
        assertNull(c.subtitle());
        assertNull(c.imageUrl());
        assertNull(c.kind());
        assertEquals(service.cards(VIEWER, List.of(hidden)).get(hidden).available(),
                service.cards(VIEWER, List.of(missing)).get(missing).available()); // var/yok ayrimi yok
    }

    @Test
    void newsImageMustBeHttpsOnBingolEduTr() {
        assertEquals("https://www.bingol.edu.tr/x/a.jpg?v=1", ShareService.safeBingolImage("http://www.bingol.edu.tr/x/a.jpg?v=1"));
        assertEquals("https://bingol.edu.tr/a.png", ShareService.safeBingolImage("https://bingol.edu.tr/a.png"));
        assertNull(ShareService.safeBingolImage("https://evil.com/a.jpg"));
        assertNull(ShareService.safeBingolImage("https://bingol.edu.tr.evil.com/a.jpg"));
        assertNull(ShareService.safeBingolImage("https://user:pw@www.bingol.edu.tr/a.jpg"));
        assertNull(ShareService.safeBingolImage("javascript:alert(1)"));
        assertNull(ShareService.safeBingolImage("https://www.bingol.edu.tr:8443/a.jpg"));
        assertNull(ShareService.safeBingolImage(null));
        assertNull(ShareService.safeBingolImage("data:image/png;base64,AAAA"));
    }

    // --- gonderi / reel ---

    @Test
    void publicPostOfPublicAccountResolves() {
        post(5, AUTHOR, "Kampus bahar");
        PostMedia m = new PostMedia();
        m.setId(55L);
        m.setPostId(5L);
        m.setThumbKey("t.jpg");
        when(postMedia.findByPostIdIn(anyCollection())).thenReturn(List.of(m));
        ShareRef ref = new ShareRef(ShareType.POST, 5);

        ShareService.Resolved r = service.publicView(ref).orElseThrow();

        assertEquals("Kampus bahar", r.title());
        assertEquals("Ayse Yilmaz", r.subtitle());
        assertEquals(55L, r.mediaId());
        assertEquals("PHOTO", r.kind());
        assertEquals("/api/posts/media/55?thumb=true", service.cards(VIEWER, List.of(ref)).get(ref).imageUrl());
    }

    @Test
    void postWithoutTextUsesAuthorNameAsTitle() {
        post(5, AUTHOR, null);

        ShareService.Resolved r = service.publicView(new ShareRef(ShareType.REEL, 5)).orElseThrow();

        assertEquals("Ayse Yilmaz", r.title());
        assertNull(r.subtitle());
    }

    @Test
    void privateAccountPostIsNotPublicButVisibleToAcceptedFollower() {
        post(5, AUTHOR, "gizli");
        when(gate.privateAmong(anyCollection())).thenReturn(Set.of(AUTHOR));
        when(gate.lockedAmong(VIEWER, Set.of(AUTHOR))).thenReturn(Set.of(AUTHOR));
        when(gate.lockedAmong(8L, Set.of(AUTHOR))).thenReturn(Set.of()); // kabul edilmis takipci
        ShareRef ref = new ShareRef(ShareType.POST, 5);

        assertTrue(service.publicView(ref).isEmpty());
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());
        assertTrue(service.cards(8L, List.of(ref)).get(ref).available());
    }

    @Test
    void deletedHiddenSuspendedOrBlockedAuthorPostsAreUnavailable() {
        Post p = post(5, AUTHOR, "x");
        ShareRef ref = new ShareRef(ShareType.POST, 5);

        p.setDeletedAt(Instant.now());
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());

        p.setDeletedAt(null);
        p.setHiddenAt(Instant.now());
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());

        p.setHiddenAt(null);
        assertTrue(service.cards(VIEWER, List.of(ref)).get(ref).available());

        when(blocks.hiddenFrom(VIEWER)).thenReturn(Set.of(AUTHOR)); // engel (iki yonlu)
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());
        assertTrue(service.publicView(ref).isPresent()); // anonim sayfa viewer'a bagli degil

        when(blocks.hiddenFrom(VIEWER)).thenReturn(Set.of());
        User u = new User();
        u.setId(AUTHOR);
        u.setDisplayName("Ayse");
        u.setStatus(UserStatus.SUSPENDED);
        when(users.findAllById(anyCollection())).thenReturn(List.of(u));
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());
        assertTrue(service.publicView(ref).isEmpty());
    }

    @Test
    void authorSeesOwnPostEvenWhenAccountIsPrivate() {
        post(5, AUTHOR, "benim");
        when(gate.lockedAmong(AUTHOR, Set.of(AUTHOR))).thenReturn(Set.of());
        ShareRef ref = new ShareRef(ShareType.POST, 5);

        assertTrue(service.cards(AUTHOR, List.of(ref)).get(ref).available());
    }

    // --- etkinlik ---

    private UserEvent event(long id, UserEvent.Status status, Long communityId) {
        UserEvent e = new UserEvent();
        e.setId(id);
        e.setTitle("Bahar Senligi");
        e.setStatus(status);
        e.setCommunityId(communityId);
        e.setStartsAt(Instant.parse("2026-11-20T10:00:00Z"));
        e.setEndsAt(Instant.parse("2026-11-20T12:00:00Z"));
        e.setCoverUrl("/files/events/ab.jpg");
        when(events.findAllById(anyCollection())).thenReturn(List.of(e));
        return e;
    }

    private Community club(long id, Community.Status status, Community.Visibility vis) {
        Community c = new Community();
        c.setId(id);
        c.setName("Fotograf Kulubu");
        c.setStatus(status);
        c.setVisibility(vis);
        when(communities.findAllById(anyCollection())).thenReturn(List.of(c));
        return c;
    }

    @Test
    void activeEventOfPublicActiveClubIsPublic() {
        event(3, UserEvent.Status.ACTIVE, 30L);
        club(30, Community.Status.ACTIVE, Community.Visibility.PUBLIC);

        ShareService.Resolved r = service.publicView(new ShareRef(ShareType.EVENT, 3)).orElseThrow();

        assertEquals("Bahar Senligi", r.title());
        assertEquals("Fotograf Kulubu", r.subtitle());
        assertEquals("/files/events/ab.jpg", r.imageUrl());
        assertNotNull(r.when());
    }

    @Test
    void pendingCancelledOrHiddenEventsAreNeverShared() {
        for (UserEvent.Status s : List.of(UserEvent.Status.PENDING_REVIEW, UserEvent.Status.CANCELLED,
                UserEvent.Status.HIDDEN, UserEvent.Status.REJECTED)) {
            event(3, s, null);
            assertTrue(service.publicView(new ShareRef(ShareType.EVENT, 3)).isEmpty(), s.name());
        }
    }

    @Test
    void privateClubEventVisibleOnlyToItsMembers() {
        event(3, UserEvent.Status.ACTIVE, 30L);
        club(30, Community.Status.ACTIVE, Community.Visibility.PRIVATE);
        CommunityMember member = mock(CommunityMember.class);
        when(member.isActive()).thenReturn(true);
        when(members.findByCommunityIdAndUserId(30L, 8L)).thenReturn(Optional.of(member));
        ShareRef ref = new ShareRef(ShareType.EVENT, 3);

        assertTrue(service.publicView(ref).isEmpty());
        assertFalse(service.cards(VIEWER, List.of(ref)).get(ref).available());
        assertTrue(service.cards(8L, List.of(ref)).get(ref).available());
    }

    @Test
    void closedClubEventIsUnavailable() {
        event(3, UserEvent.Status.ACTIVE, 30L);
        club(30, Community.Status.HIDDEN, Community.Visibility.PUBLIC);

        assertTrue(service.publicView(new ShareRef(ShareType.EVENT, 3)).isEmpty());
    }

    // --- gonderim dogrulamasi ---

    @Test
    void requireVisibleRejectsUnknownTypeBadIdAndInvisibleContent() {
        mockNews(newsItem(1, ContentType.HABER, false, null));

        assertEquals(new ShareRef(ShareType.NEWS, 1), service.requireVisible(VIEWER, "news", 1L));
        for (Object[] bad : new Object[][] {{"COMMENT", 1L}, {null, 1L}, {"NEWS", null}, {"NEWS", -4L}, {"NEWS", 99L}}) {
            ApiException e = assertThrows(ApiException.class,
                    () -> service.requireVisible(VIEWER, (String) bad[0], (Long) bad[1]));
            assertEquals("SHARE_TARGET_INVALID", e.code());
            assertEquals(422, e.status().value());
        }
    }

    @Test
    void recipientCardsReuseThePublicResolutionAndFallBackPerViewer() {
        post(5, AUTHOR, "herkese acik");
        when(blocks.hiddenFrom(AUTHOR)).thenReturn(Set.of(11L)); // 11 yazarla engel iliskisinde
        when(blocks.hiddenFrom(11L)).thenReturn(Set.of(AUTHOR));
        ShareRef ref = new ShareRef(ShareType.POST, 5);

        Map<Long, ShareCard> cards = service.cardsForViewers(ref, List.of(7L, 8L, 11L));

        assertTrue(cards.get(7L).available());
        assertEquals(cards.get(7L), cards.get(8L)); // ayni kart (tek anonim cozum)
        assertFalse(cards.get(11L).available());
    }

    @Test
    void neutralCardKeepsOnlyTypeAndAvailability() {
        ShareCard full = new ShareCard("POST", 5L, true, "t", "s", "/x", "PHOTO", "https://bukampus.com.tr/s/p/5");

        ShareCard n = full.neutral();

        assertTrue(n.available());
        assertEquals("POST", n.type());
        assertNull(n.title());
        assertNull(n.imageUrl());
    }
}
